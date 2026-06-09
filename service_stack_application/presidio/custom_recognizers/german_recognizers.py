"""
Custom German PII Recognizers for Presidio
Provides recognizers for German-specific PII types:
- DE_IBAN (German IBAN)
- DE_STEUER_ID (German Tax ID)
- DE_ADDRESS (German addresses)
- DE_PHONE (German phone numbers)
- DE_POSTAL_CODE (German postal codes)
"""

import re
from typing import List, Optional, Tuple
from presidio_analyzer import Pattern, PatternRecognizer
from presidio_analyzer.nlp_engine import NlpArtifacts


class GermanIbanRecognizer(PatternRecognizer):
    """
    Recognizes German IBANs (DE + 20 alphanumeric chars).
    Format: DEkk BBBB BBBB CCCC CCCC CC
    """

    def __init__(
        self,
        supported_language: str = "de",
        supported_entity: str = "DE_IBAN",
        context: Optional[List[str]] = None,
    ):
        # German IBAN regex: DE + 2 check digits + 8 bank code + 10 account number
        patterns = [
            Pattern(
                name="german_iban",
                regex=r"\bDE\d{2}[A-Z0-9]{18}\b",
                score=0.95,
            ),
            Pattern(
                name="german_iban_formatted",
                regex=r"\bDE\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{2}\b",
                score=0.9,
            ),
        ]
        context = context or ["iban", "konto", "bankverbindung", "kontonummer", "überweisung"]
        super().__init__(
            supported_entity=supported_entity,
            patterns=patterns,
            context=context,
            supported_language=supported_language,
        )

    def validate_result(self, pattern_text: str) -> bool:
        """Validate IBAN checksum using MOD-97-10 algorithm."""
        # Remove spaces
        iban = pattern_text.replace(" ", "").upper()
        if not iban.startswith("DE") or len(iban) != 22:
            return False
        # Move first 4 chars to end: DE89 -> 89DE
        rearranged = iban[4:] + iban[:4]
        # Convert letters to numbers (A=10, B=11, ...)
        numeric = ""
        for char in rearranged:
            if char.isalpha():
                numeric += str(ord(char) - ord('A') + 10)
            else:
                numeric += char
        # MOD-97-10 check
        return int(numeric) % 97 == 1


class GermanSteuerIdRecognizer(PatternRecognizer):
    """
    Recognizes German Steueridentifikationsnummer (11 digits).
    Format: 11 digits, no formatting.
    """

    def __init__(
        self,
        supported_language: str = "de",
        supported_entity: str = "DE_STEUER_ID",
        context: Optional[List[str]] = None,
    ):
        patterns = [
            Pattern(
                name="german_steuer_id",
                regex=r"\b\d{11}\b",
                score=0.7,  # Lower score, validated by checksum
            ),
        ]
        context = context or ["steuer-id", "steueridentifikationsnummer", "steuernummer", "idnr", "identifikationsnummer"]
        super().__init__(
            supported_entity=supported_entity,
            patterns=patterns,
            context=context,
            supported_language=supported_language,
        )

    def validate_result(self, pattern_text: str) -> bool:
        """Validate Steuer-ID checksum (algorithm per German tax authority)."""
        if len(pattern_text) != 11 or not pattern_text.isdigit():
            return False
        # Steuer-ID validation: weighted sum modulo 11
        weights = [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
        total = sum(int(d) * w for d, w in zip(pattern_text[:10], weights))
        check_digit = (11 - (total % 11)) % 11
        if check_digit == 10:
            check_digit = 0
        return check_digit == int(pattern_text[10])


class GermanPostalCodeRecognizer(PatternRecognizer):
    """
    Recognizes German postal codes (5 digits).
    """

    def __init__(
        self,
        supported_language: str = "de",
        supported_entity: str = "DE_POSTAL_CODE",
        context: Optional[List[str]] = None,
    ):
        patterns = [
            Pattern(
                name="german_postal_code",
                regex=r"\b\d{5}\b",
                score=0.6,  # Low score, needs context
            ),
        ]
        context = context or ["plz", "postleitzahl", "postleitzahl:", "wohnort", "stadt"]
        super().__init__(
            supported_entity=supported_entity,
            patterns=patterns,
            context=context,
            supported_language=supported_language,
        )

    def validate_result(self, pattern_text: str) -> bool:
        """Basic validation: German postal codes are 01000-99999."""
        try:
            code = int(pattern_text)
            return 1000 <= code <= 99999
        except ValueError:
            return False


class GermanPhoneRecognizer(PatternRecognizer):
    """
    Recognizes German phone numbers in various formats.
    """

    def __init__(
        self,
        supported_language: str = "de",
        supported_entity: str = "DE_PHONE_NUMBER",
        context: Optional[List[str]] = None,
    ):
        patterns = [
            Pattern(
                name="german_phone_mobile",
                regex=r"\b(?:\+49|0049|0)1[5-7]\d{8,9}\b",
                score=0.85,
            ),
            Pattern(
                name="german_phone_landline",
                regex=r"\b(?:\+49|0049|0)(?:[2-9]\d{1,4})\d{4,8}\b",
                score=0.8,
            ),
            Pattern(
                name="german_phone_formatted",
                regex=r"\b(?:\+49|0049|0)\s?\d{2,5}[\s/-]?\d{4,8}\b",
                score=0.75,
            ),
        ]
        context = context or ["telefon", "tel", "handy", "mobil", "rufnummer", "fon"]
        super().__init__(
            supported_entity=supported_entity,
            patterns=patterns,
            context=context,
            supported_language=supported_language,
        )


class GermanAddressRecognizer(PatternRecognizer):
    """
    Recognizes German street addresses.
    Pattern: Street name + house number, optionally with postal code + city.
    """

    def __init__(
        self,
        supported_language: str = "de",
        supported_entity: str = "DE_ADDRESS",
        context: Optional[List[str]] = None,
    ):
        patterns = [
            Pattern(
                name="german_address_full",
                regex=r"\b[A-ZÄÖÜ][a-zäöüß]+\s+(?:straße|strasse|weg|platz|allee|gasse|ring|ufer|damm|chaussee|promenade)\s+\d+[a-z]?(?:\s*,?\s*\d{5}\s+[A-ZÄÖÜ][a-zäöüß]+)?\b",
                score=0.85,
            ),
            Pattern(
                name="german_address_short",
                regex=r"\b[A-ZÄÖÜ][a-zäöüß]+\s+(?:str\.|straße|weg|platz|allee)\s+\d+[a-z]?\b",
                score=0.75,
            ),
        ]
        context = context or ["adresse", "anschrift", "wohnhaft", "straße", "str.", "plz", "ort"]
        super().__init__(
            supported_entity=supported_entity,
            patterns=patterns,
            context=context,
            supported_language=supported_language,
        )


# Registry of all custom recognizers
CUSTOM_RECOGNIZERS = [
    GermanIbanRecognizer(),
    GermanSteuerIdRecognizer(),
    GermanPostalCodeRecognizer(),
    GermanPhoneRecognizer(),
    GermanAddressRecognizer(),
]

# Entity types added by custom recognizers
CUSTOM_ENTITIES = [
    "DE_IBAN",
    "DE_STEUER_ID",
    "DE_POSTAL_CODE",
    "DE_PHONE_NUMBER",
    "DE_ADDRESS",
]