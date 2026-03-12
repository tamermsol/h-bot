# H-Bot Design — Scope & Plan

## Project Understanding

H-Bot is a **consumer IoT smart home app** built in Flutter for iOS/Android. It's the companion app for Momentum Solutions (MSOL) physical hardware — switches, sensors, lights, shutters. The app pairs devices over WiFi, controls them in real-time, and manages scenes/automations. Target users are non-technical homeowners who expect Apple Home / Google Home levels of polish. White-label: no protocol or firmware branding visible.

## Scope of Work

### Phase 1: Foundation & Add Device Flow ← **NOW**
- **Design Token System** — Complete color palette, typography scale, spacing, elevation, radius, component specs
- **Add Device Flow** — Full mockup specs for all 4 steps, all states (idle, loading, success, error, timeout), iOS and Android variants
- **Deliverables:** `01-DESIGN-TOKENS.md`, `02-ADD-DEVICE-FLOW.md`

### Phase 2: Home Dashboard & Device Control
- Dashboard layout with device cards, room tabs, sensor data presentation
- Device Control screen specs per device type (switch, light, sensor, shutter)
- Timer management UI
- Empty states, loading skeletons
- **Deliverables:** `03-HOME-DASHBOARD.md`, `04-DEVICE-CONTROL.md`

### Phase 3: Scenes, Profile & Settings
- Scenes screen and scene editor
- Profile screen with settings
- Avatar picker, appearance, notifications
- **Deliverables:** `05-SCENES.md`, `06-PROFILE.md`

### Phase 4: Auth, Homes/Rooms, Sharing, WiFi
- Authentication flow (sign in, sign up, forgot password, OTP)
- Homes & Rooms management
- Device sharing flows
- WiFi profiles
- **Deliverables:** `07-AUTH.md`, `08-HOMES-ROOMS.md`, `09-SHARING.md`, `10-WIFI-PROFILES.md`

### Phase 5: App Identity & Polish
- App icon/logo concepts
- Empty state illustrations
- iPad responsive specs
- Component library summary
- **Deliverables:** `11-APP-IDENTITY.md`, `12-EMPTY-STATES.md`, `13-IPAD-RESPONSIVE.md`, `14-COMPONENT-LIBRARY.md`

## Questions / Clarifications Needed

1. **Brand colors:** The brief mentions the current blue "may not match premium IoT vibe." Is Tim open to a completely new palette, or should we evolve from the existing blue?
2. **Logo:** Any existing brand marks, wordmarks, or preferences? Letters, icon, abstract?
3. **Illustrations:** Budget for custom illustrations, or should we use icon compositions / Lottie animations?
4. **Dark mode:** Confirmed deprioritized — designing light-only for now, but should tokens be structured for future dark mode?
5. **Android device discovery:** The brief mentions auto-scan on Android. Should the visual design differ significantly from iOS, or keep it as similar as possible?

## Proposed Approach

- **Format:** Detailed markdown specs with exact dimensions, colors, spacing, and widget mapping for Flutter
- **Style direction:** Clean, premium, trust-building. Think Apple Home meets Philips Hue. Soft shadows, generous whitespace, rounded corners, subtle gradients for depth. Blue-based palette evolved toward a more sophisticated slate-blue.
- **Tools:** Markdown spec documents with precise Flutter-implementable values. Each screen described with exact layout hierarchy, dimensions, colors, and states.
- **Proceeding with assumptions** for questions above (can revise): evolving the blue palette, structuring for future dark mode, icon-composition empty states, keeping Android/iOS similar where possible.

## Timeline Estimate

| Phase | Effort |
|-------|--------|
| Phase 1: Tokens + Add Device | Delivering now |
| Phase 2: Dashboard + Device Control | Next session |
| Phase 3: Scenes + Profile | Following session |
| Phase 4: Auth + Rooms + Sharing | Following |
| Phase 5: Identity + Polish | Final |
