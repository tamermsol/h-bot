# Plan: Channel Controls & iPad Optimization

## Device Channel Counts: 1, 2, 4, 8

## Part 1: Channel Controls (Priority)

### Dashboard Device Cards
- **1 channel** → Current card (icon + name + toggle). No change.
- **2 channels** → Card stays in grid, shows 2 toggle rows below device name
- **4 channels** → Full-width card (spans both columns), 2x2 grid of channel toggles
- **8 channels** → Full-width card, 2x4 grid of channel toggles + All On/Off

### Device Control Screen — All Channels Visible
No tabs. All channels visible simultaneously in a responsive grid:

**1 channel:**
```
┌──────────────────────────────────┐
│  ←  Living Room Light      ⚙️ ⋮ │
│         ┌───────────┐           │
│         │    💡      │           │
│         │    ON      │           │
│         └───────────┘           │
│      ┌──────────●━━━━┐         │
│      └───────────────┘         │
│  Details                        │
│  ┌─────────────────────────┐   │
│  │  Signal    ·  -45 dBm  │   │
│  └─────────────────────────┘   │
└──────────────────────────────────┘
```

**4 channels:**
```
┌──────────────────────────────────┐
│  ←  Power Board            ⚙️ ⋮ │
│                                  │
│  ┌──────────┐  ┌──────────┐    │
│  │ 💡 Lamp 1│  │ 💡 Lamp 2│    │
│  │    ON    │  │    OFF   │    │
│  │  ──●━━   │  │  ━━●──   │    │
│  └──────────┘  └──────────┘    │
│  ┌──────────┐  ┌──────────┐    │
│  │ ⚡ Fan   │  │ ⚡ Outlet│    │
│  │    ON    │  │    OFF   │    │
│  └──────────┘  └──────────┘    │
│                                  │
│  ┌─ All On ─┐  ┌─ All Off ─┐  │
│                                  │
│  Details                        │
│  ┌─────────────────────────┐   │
│  │  Signal    ·  -38 dBm  │   │
│  └─────────────────────────┘   │
└──────────────────────────────────┘
```

**8 channels:**
```
┌──────────────────────────────────┐
│  ←  Main Board             ⚙️ ⋮ │
│                                  │
│  ┌──────────┐  ┌──────────┐    │
│  │ 💡 Ch 1  │  │ 💡 Ch 2  │    │
│  │    ON    │  │    OFF   │    │
│  │  ──●━━   │  │  ━━●──   │    │
│  └──────────┘  └──────────┘    │
│  ┌──────────┐  ┌──────────┐    │
│  │ ⚡ Ch 3  │  │ ⚡ Ch 4  │    │
│  │    ON    │  │    OFF   │    │
│  └──────────┘  └──────────┘    │
│  ┌──────────┐  ┌──────────┐    │
│  │ 💡 Ch 5  │  │ 💡 Ch 6  │    │
│  │    OFF   │  │    ON    │    │
│  └──────────┘  └──────────┘    │
│  ┌──────────┐  ┌──────────┐    │
│  │ ⚡ Ch 7  │  │ ⚡ Ch 8  │    │
│  │    OFF   │  │    ON    │    │
│  └──────────┘  └──────────┘    │
│                                  │
│  ┌─ All On ─┐  ┌─ All Off ─┐  │
│                                  │
│  Details                        │
└──────────────────────────────────┘
```

**Channel card design:**
- Each channel = a mini card with icon, custom name, state, and toggle
- 2-column grid layout (always)
- Active: primary color left border, icon colored
- Inactive: neutral border, grey icon
- Long-press → rename/type dialog
- Tap anywhere on card → toggle

### Implementation
1. Create `ChannelCard` widget (reusable mini card)
2. Create `ChannelGrid` widget (2-col grid of ChannelCards + bulk controls)
3. Refactor `device_control_screen.dart` to use ChannelGrid
4. Update `DeviceCard` (dashboard) for multi-channel inline display
5. Update dashboard grid to handle variable-height cards

---

## Part 2: iPad/Tablet Optimization

### Breakpoints
| Width | Layout |
|---|---|
| < 600px | Phone — standard layout |
| 600-899px | Tablet portrait — 500px centered |
| ≥ 900px | Tablet landscape — 500px centered, 3-col device grid |

### Implementation
1. `ResponsiveShell` widget — centers content at max 500px on tablet
2. `HBotLayout` helpers — isTablet, padding, grid columns
3. Wrap HomeScreen (body + bottom nav)
4. Wrap all screens
5. Constrain dialogs/sheets to 500px
6. iPad landscape: 3-column device grid

---

## Combined Build Order

### Commit 1: Channel foundation
- [ ] `ChannelCard` widget
- [ ] `ChannelGrid` widget  
- [ ] Refactor device_control_screen to use them

### Commit 2: Dashboard multi-channel
- [ ] Update DeviceCard for multi-channel inline
- [ ] Variable-height dashboard grid

### Commit 3: Tablet foundation
- [ ] `ResponsiveShell` + `HBotLayout`
- [ ] Wrap HomeScreen + auth screens

### Commit 4: Tablet all screens
- [ ] Wrap remaining screens
- [ ] Constrain dialogs/sheets
- [ ] iPad landscape 3-col grid

### Commit 5: Polish + Build 103
- [ ] Test all channel counts (1, 2, 4, 8)
- [ ] Test tablet layouts
- [ ] Version bump → build + deploy
