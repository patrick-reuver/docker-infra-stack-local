"""
Custom Recognizers Package for Presidio
Exports all German PII recognizers for automatic loading.
"""

from .german_recognizers import (
    CUSTOM_RECOGNIZERS,
    CUSTOM_ENTITIES,
    GermanIbanRecognizer,
    GermanSteuerIdRecognizer,
    GermanPostalCodeRecognizer,
    GermanPhoneRecognizer,
    GermanAddressRecognizer,
)

__all__ = [
    "CUSTOM_RECOGNIZERS",
    "CUSTOM_ENTITIES",
    "GermanIbanRecognizer",
    "GermanSteuerIdRecognizer",
    "GermanPostalCodeRecognizer",
    "GermanPhoneRecognizer",
    "GermanAddressRecognizer",
]