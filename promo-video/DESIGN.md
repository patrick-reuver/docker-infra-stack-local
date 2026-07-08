# DESIGN.md

## Overview
Dark cinematic tech aesthetic. Deep navy-black canvas with cyan accent as primary brand color. Clean sans-serif typography with gradient title treatments. Atmosphere through radial glows, subtle grid patterns, and border-defined content areas. Inspired by the Mermaid architecture diagrams used in the docker-infra-stack README — dark backgrounds with bright colored accents per layer.

## Colors

| Role | Hex | Usage |
|------|-----|-------|
| Canvas | `#0a0a0f` | Primary background |
| Surface | `#12121a` | Card/secondary surfaces |
| Text primary | `#ffffff` | Headlines, key labels |
| Text secondary | `#94a3b8` | Body text, subtitles |
| Accent cyan | `#22d3ee` | Brand accent, highlights, tags |
| Accent purple | `#a78bfa` | Core Infrastructure layer |
| Accent amber | `#fbbf24` | Platform Services layer |
| Accent rose | `#fb7185` | AI & Security layer |
| Accent blue | `#60a5fa` | Access layer |
| Border subtle | `rgba(255,255,255,0.08)` | Card/container borders |
| Grid line | `rgba(34,211,238,0.03)` | Background grid pattern |

## Typography

| Role | Size | Weight | Family |
|------|------|--------|--------|
| Hero title | 96px | 700 | System sans-serif |
| Section heading | 72px | 600 | System sans-serif |
| Sub-heading | 54px | 600 | System sans-serif |
| Subtitle | 36px | 400 | System sans-serif |
| Body | 32px | 400 | System sans-serif |
| Tags/labels | 20-24px | 500 | System sans-serif |
| Layer items | 18px | 400 | System sans-serif |

System font stack: `'SF Pro Display', -apple-system, 'Helvetica Neue', 'Segoe UI', Arial, sans-serif`

## Components

### Principle Cards
Rounded 16px cards with subtle border (`rgba(255,255,255,0.08)`), semi-transparent background (`rgba(255,255,255,0.03)`), centered emoji icon, title and description. Ambient backdrop-blur. Entrance via bounce-scale.

### Architecture Layers
Horizontal bars with left accent border (colored per layer), layer name (uppercase, accent color) on left, service items (secondary text) on right, separated by dashed line. Slide-in from left with stagger.

### Flow Nodes
Rounded 12px nodes with border, semi-transparent background. Active state gets cyan border + glow. Connected by arrow symbols. Sequential reveal with scale-bounce entrance.

### Outro Signature
Centered logo, subtitle line, footer with GitHub reference and MIT badge, personal attribution line. Fade-in sequence from bottom.

## Do's & Don'ts

- DO use cyan as the primary accent throughout
- DO keep backgrounds dark — no light mode
- DO use 8-10 visual elements per scene (density matters on video)
- DO stagger animations — never animate everything at once
- DON'T use flat colors without texture (glows, grids, gradients)
- DON'T use font sizes under 18px — invisible on video
- DON'T center everything — use zone-based layouts
- DON'T leave dead space — fill the frame
