# Brand DNA — H-Bot

> This document captures the *essence* of the H-Bot brand as expressed through h-bot.tech, distilled into principles that drive every design decision in the mobile app.

---

## 1. Brand Feeling

**Five words that ARE H-Bot:**
- **Confident** — Large type, bold claims, no hedging
- **Technical** — Precision in layout, data-forward UI
- **Calm** — Dark spaces, breathing room, no visual noise
- **Premium** — Every pixel has purpose; nothing is generic
- **Approachable** — Despite the tech, the language is simple: "Smart Home, Simplified"

**Five words that are NOT H-Bot:**
- Playful, Quirky, Loud, Cluttered, Cheap

**Mood Board in Words:**
A midnight control room. Screens glow blue. Everything is under control. You're in charge, and the technology works *for* you — not the other way around.

---

## 2. Color Relationships

The H-Bot palette is NOT a random set of blues. It's a carefully orchestrated light-on-dark system.

### The Core Relationship: Deep Night + Electric Blue

| Role | Color | Hex | Usage |
|---|---|---|---|
| **Void** | Near-black with blue undertone | `#010510` | Page background — NOT pure black, has warmth |
| **Primary** | Electric Blue | `#0883FD` | CTAs, interactive elements, gradient start |
| **Primary Light** | Sky Blue | `#8CD1FB` | Gradient endpoint, highlights, secondary accent |
| **Mid Blue** | Teal Blue | `#1070AD` | Decorative lines, secondary gradients |
| **Bright Blue** | Cyan | `#2FB8EC` | Tertiary accent, animation midpoint |

### How Colors Work Together

1. **Gradient text** is the signature move: `#0883FD → #8CD1FB` (left to right, 90°). This is used ONLY on key phrases — "Intelligent Solutions", "Products", "Total control", "Smart devices". It's the brand's voice.

2. **Background depth** uses layered radial gradients: `rgba(9,73,114,0.2-0.3)` center → `rgba(1,5,16,0.2-0.3)` edge. This creates subtle pools of blue light on the dark background — like ambient lighting.

3. **Borders** are near-invisible: `#181B1F` — just enough to separate elements without creating visual noise.

4. **Text hierarchy through opacity, not color changes:**
   - Hero text: `#FFFFFF` (pure white)
   - Body text: `rgb(199,201,204)` / `rgb(215,215,215)` (warm gray)
   - Secondary text: `rgb(180,180,180)` (cooler gray)
   - Muted text: `rgb(180,180,180)` at smaller sizes

5. **Cards** use a slightly elevated dark: `#1A202B` (navy-tinted dark) with `#181B1F` borders. NOT pure gray — always has blue undertone.

6. **Decorative gradients** use the full blue spectrum: `#CBD9DE → #1070AD` at 225° or 77° for dividers and accent shapes.

### The Rule of Blue

Every non-neutral color in H-Bot traces back to blue. There is no orange, no green (except for success states), no purple. The brand is monochromatic blue + neutrals. This creates extreme visual cohesion.

---

## 3. Depth & Hierarchy

The website creates depth through 5 layers:

```
Layer 5: Gradient text (foreground highlight)     — #0883FD→#8CD1FB
Layer 4: White text on dark                       — #FFFFFF on #010510
Layer 3: Cards / elevated surfaces                — #1A202B + blur(30-45px)
Layer 2: Subtle radial glow backgrounds           — rgba(9,73,114,0.2-0.3)
Layer 1: Deep background                          — #010510
```

**Key insight:** The website NEVER uses drop shadows for elevation. Instead:
- **Backdrop blur** (glassmorphism) for floating nav
- **Subtle border** (#181B1F) for card edges
- **Inset shadows** (`rgba(0,0,0,0.12) 0 0 5.78px inset`) for recessed elements (grid cells)
- **Background gradients** for section separation

This creates a sense of depth without the "floating card" look that screams Material Design.

---

## 4. What Makes It Premium (Not Generic)

| Generic Bootstrap | H-Bot's Approach |
|---|---|
| Drop shadows on everything | Subtle borders + backdrop blur |
| Random accent colors | Monochromatic blue palette |
| System fonts at safe sizes | Readex Pro at bold sizes (72-89px headers) |
| Tight spacing | Generous whitespace (32px gaps in cards) |
| Rounded rect buttons with solid fills | Gradient buttons, ghost borders |
| Generic card with white bg | Dark cards with blue-tinted borders |
| Stock hero with text overlay | Typographic hero with gradient text accent |
| Every word same weight | Clear weight hierarchy: 700→600→500→400→300 |

**The secret sauce:**
1. Restraint — very few colors, very few patterns, repeated consistently
2. Scale — headers are LARGE (72-89px), creating confidence
3. Spacing — nothing feels cramped
4. Gradient text — a single signature element that says "this is H-Bot"
5. Blue-tinted neutrals — even the "black" and "gray" lean blue

---

## 5. Typography System

**Website fonts:**
- **Readex Pro** — Primary for everything (headers through body)
- **Satoshi** — Secondary, used for the tagline "Bringing ease and intelligence to your home"

**The weight system creates hierarchy:**
```
700  Bold      → Hero statements, key numbers
600  SemiBold  → Section headings, feature titles
500  Medium    → Sub-headings, buttons, labels
400  Regular   → Body text, descriptions
300  Light     → Fine print, secondary descriptions
```

**Size scale (website → mobile equivalent):**
```
Website     Mobile App    Usage
89px        32px          Hero/splash only
72px        28px          Section hero
60px        24px          Section title
52px        22px          Feature title
42px        20px          Sub-section
34px        18px          Card title
26px        16px          Body large
20px        15px          Body
18px        14px          Body small
17px        13px          Caption
16px        13px          Caption
14px        12px          Label
12px        11px          Overline/tag
10px        10px          Fine print
```

---

## 6. Micro-Interactions & Motion Language

**Observed on the website:**
- **Scroll-triggered reveals** — sections fade in as you scroll
- **Gradient line animations** — decorative lines with traveling light effect
- **Tab switching** — smooth gradient fill transition on active tab
- **Hover states** — subtle scale/opacity changes, not dramatic
- **No bouncy/springy animations** — everything is smooth, controlled, linear or ease-out

**Motion Principles for the App:**
1. **Smooth, not playful** — Use `Curves.easeOut` and `Curves.easeInOut`, never `Curves.bounceOut`
2. **Duration: 200-300ms** for micro-interactions, 400-500ms for page transitions
3. **Subtle scale** — pressed states scale to 0.97, not 0.9
4. **Gradient transitions** — when toggling device states, the gradient should smoothly appear
5. **No rotation, no shake** — the brand is calm and controlled
6. **Loading = pulsing gradient** — skeleton screens should pulse with the brand blue gradient

---

## 7. Dark → Light Translation

The website is dark-mode. The app is light-mode primary. Here's how to translate:

| Website (Dark) | App Light Mode | Reasoning |
|---|---|---|
| `#010510` background | `#F8F9FB` background | Blue-tinted off-white (NOT pure white) |
| `#FFFFFF` text | `#0A1628` text | Deep navy-black (NOT pure black) |
| `rgb(199,201,204)` secondary text | `#5A6577` | Muted blue-gray |
| `#1A202B` card background | `#FFFFFF` card background | White cards on tinted background |
| `#181B1F` card border | `#E8ECF1` card border | Same idea: barely-there separation |
| `#0883FD→#8CD1FB` gradient | **SAME** | The gradient works on both light and dark |
| Backdrop blur | Subtle elevation shadow | Different technique, same depth intent |
| Inset shadow grid | Subtle border + fill | Light mode equivalent |

### The Key Insight

The **brand gradient** (`#0883FD→#8CD1FB`) is the constant. It works on dark backgrounds AND light backgrounds. This is the thread that ties the website to the app.

In light mode:
- Use the gradient for primary buttons, active states, and key accent text
- Use `#0883FD` as the flat primary color for icons and interactive elements
- Keep surfaces blue-tinted (off-white, not pure white; blue-gray, not pure gray)
- Reserve pure white for elevated cards

---

## 8. Logo Analysis

The H-Bot logo (from favicon and nav):
- **Mark:** Stylized "H" letterform integrated into a geometric/tech shape
- **Color:** White on dark, or could be gradient blue
- **Style:** Clean, geometric, modern sans-serif
- **Treatment:** Used at small sizes in nav, clean silhouette

For the app:
- Use the logomark (H symbol) for splash screen and app icon
- App icon should use the `#0883FD→#8CD1FB` gradient as background with white logomark
- In-app, use the wordmark "H-Bot" with gradient text treatment on dark surfaces

---

## 9. Icon Style

The website uses:
- **Line-style icons** (not filled)
- Clean, consistent stroke weight
- Small size: 16-24px
- No color on icons (white on dark) — the brand doesn't rely on icon color

For the app:
- Use **Phosphor Icons** or **Lucide** (line style, 1.5px stroke)
- Icon size: 24px standard, 20px in tight spaces
- Color: `$onSurface` by default, `$primary` when active
- Device type icons should be custom but follow the same line weight

---

## 10. Summary: Brand Design Principles

1. **Monochromatic Blue** — Every accent is blue. No exceptions.
2. **Gradient as Signature** — `#0883FD→#8CD1FB` is the brand mark. Use it deliberately.
3. **Calm Confidence** — Large type, generous space, no clutter.
4. **Blue-Tinted Neutrals** — Even "black" and "white" lean blue.
5. **Restraint Over Decoration** — Fewer elements, better executed.
6. **Depth Through Layers** — Blur, borders, gradients — not shadows.
7. **Typography Does the Work** — Size and weight create hierarchy, not color.
8. **Smooth Motion** — Controlled, professional, never playful.
