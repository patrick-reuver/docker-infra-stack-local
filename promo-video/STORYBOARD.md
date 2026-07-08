# STORYBOARD.md — docker-infra-stack Promo

**Global Direction:** Dark cinematic, cyan-accented, architectural reveal. Clean typography with gradient titles. 1920×1080, 30fps, ~55 seconds total. Transitions: CSS blur crossfades between beats.

**Design System:** DESIGN.md
**Script:** SCRIPT.md
**TTS Voice:** `af_nova` (English, warm female)

---

## Beat 1 — Hook (0s–7s)

**Timing:** 0.0s – 6.5s (TTS: "Your infrastructure. Local. Secure. Open Source.")
**Mood:** Bold, clean, confident. Dark canvas with a low cyan glow.

**Elements:**
- `#b1-title` — "docker-infra-stack" — 96px gradient cyan/white, centered
- `#b1-sub` — "Self-hosted Infrastructure Stack" — 32px gray subtitle
- `#b1-tags` — "LOCAL · SECURE · OPEN SOURCE" — 20px cyan uppercase tags

**Animation:**
- Title: `gsap.from` y:-80, opacity:0, 0.9s power3.out at t=0.0
- Subtitle: `gsap.from` y:40, opacity:0, 0.7s power2.out at t=0.7
- Tags: `gsap.from` y:30, opacity:0, 0.6s power2.out at t=2.0

**Exit:** All fade out 0.6s starting at t=5.5

---

## Beat 2 — The Why (7s–18s)

**Timing:** 7.0s – 17.5s (TTS: "Why build your own stack? ... Privacy isn't a checkbox, it's the foundation.")
**Mood:** Reflective, grounding. Warm glow transition from cyan to subtle amber.

**Elements:**
- `#b2-heading` — "Why build your own stack?" — 54px heading
- `#b2-card-1` — 🔒 Privacy by Design — "PII protection at every layer"
- `#b2-card-2` — 🏠 Local First — "No cloud lock-in, runs locally"
- `#b2-card-3` — ⚡ Full Control — "Open source, your data, your rules"

**Animation:**
- Heading: fade-in from y:-30 at t=7.2
- Cards: staggered bounce-in (scale:0.9→1, opacity:0→1) at t=8.2 / 8.7 / 9.2
- Cards ambient: gentle y-pulse 2s yoyo repeat

**Exit:** All fade out 0.5s at t=16.8

---

## Beat 3 — Architecture (18s–38s)

**Timing:** 18.0s – 37.0s (TTS: "The architecture builds from the ground up... everything runs on your hardware.")
**Mood:** Precision, structure, progressive disclosure. Building from foundation upward.

**Layout:** Layer stack centered in frame. Layer name LEFT, services RIGHT, connected by line. Colored accent border per layer matching DESIGN.md layer colors.

**Elements:**
- `#b3-heading` — "The Architecture" — 72px, centered
- Layer rows (bottom to top):
  - 🔮 **Core** — PostgreSQL + pgvector · Redis · MinIO (purple)
  - 🟡 **Platform** — Infisical · Langfuse · ClickHouse · MCP Bridge (amber)
  - 🌸 **AI & Security** — Presidio · LiteLLM · Privacy Adapter (rose)
  - 🔵 **Access** — Traefik Reverse Proxy (blue)
  - 🟢 **Consumer** — Twenty CRM · Second Brain · Hoppscotch (cyan)
- `#b3-cta` — "Everything runs on your machine"

**Animation:**
- Heading: fade-in at t=18.2
- Layers: slide-in from left staggered 1.5s apart (Core at 19.5, Platform at 21.0, AI at 22.5, Access at 24.0, Consumer at 25.5)
- CTA: fade-up at t=29.0
- Layers get a subtle active glow on reveal

**Exit:** All fade out 0.6s at t=36.0

---

## Beat 4 — Flow (38s–50s)

**Timing:** 38.0s – 49.5s (TTS: "Here's how a request flows... Privacy isn't a feature, it's the architecture.")
**Mood:** Process, clarity, sequential. Step-by-step flow visualization.

**Elements:**
- `#b4-heading` — "How a Request Flows" — 54px
- Flow nodes (horizontal row with arrows):
  - Hermes Agent → Presidio (PII detection) → LiteLLM Gateway → ☁️ Model Provider → Deanonymized Response
- `#b4-cta` — "Privacy isn't a feature — it's the architecture"

**Animation:**
- Heading: fade-in at t=38.2
- Sequential node reveal: each node scales in + glows cyan when active, arrow appears between
- Hermes: 39.0, Presidio: 40.0, LiteLLM: 42.0, Provider: 43.5, Return: 45.0
- CTA: fade-up at t=47.0

**Exit:** All fade out 0.5s at t=49.0

---

## Beat 5 — Outro (50s–58s+)

**Timing:** 50.0s – 58.0s+ (TTS: "docker-infra-stack. Open Source. Local. Your data, your control. Ready to self-host.")
**Mood:** Resolve, confidence, calm. Clean signature card.

**Elements:**
- `#b5-title` — "docker-infra-stack" — 80px gradient
- `#b5-sub` — "Open Source · Local · Your Data, Your Control" — 28px
- `#b5-links` — GitHub link + MIT badge
- `#b5-credit` — "Patrick Reuver — Digi-Pal"

**Animation:**
- Title: fade-up at t=50.2
- Subtitle: fade-up at t=51.5
- Links + badge: fade-up at t=53.0
- Credit: fade-up at t=54.5
- Title gentle pulse: scale 1.02 yoyo

**Hold:** Beat holds to end of audio (~58s+), then fade to black.

---

## Transitions

| From | To | Type | Duration |
|------|----|------|----------|
| Beat 1 | Beat 2 | CSS fade (opacity crossfade) | 0.5s |
| Beat 2 | Beat 3 | CSS blur crossfade | 0.5s |
| Beat 3 | Beat 4 | Hard cut (context change) | 0s |
| Beat 4 | Beat 5 | CSS fade | 0.5s |

## Audio

- Narration: TTS via `npx hyperframes tts`, voice `af_nova`
- Background music: None for first draft
- SFX: None for first draft
