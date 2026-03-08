# Channel Type Feature - UI Guide

## User Interface Overview

This guide shows the visual appearance and interaction flow for the channel type feature.

## 1. Device Control Screen - Default View

### Multi-Channel Relay (Grid Layout)
```
┌─────────────────────────────────────────┐
│  Smart Relay                      [⋮]   │
├─────────────────────────────────────────┤
│                                         │
│   ┌─────────┐  ┌─────────┐            │
│   │    ⚡    │  │    💡    │            │
│   │         │  │         │            │
│   │Channel 1│  │Living Rm│            │
│   └─────────┘  └─────────┘            │
│                                         │
│   ┌─────────┐  ┌─────────┐            │
│   │    ⚡    │  │    💡    │            │
│   │         │  │         │            │
│   │Channel 3│  │Bedroom  │            │
│   └─────────┘  └─────────┘            │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │      Bulk Controls              │   │
│  │  [All ON]      [All OFF]        │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

**Legend:**
- ⚡ = Switch type (power icon)
- 💡 = Light type (lightbulb icon)
- Gray icons = OFF state
- Colored icons = ON state

## 2. Long Press Interaction

### Step 1: Long Press on Channel
```
User Action: Long press on "Living Rm" channel
              ↓
┌─────────────────────────────────────────┐
│   ┌─────────┐  ┌─────────┐            │
│   │    ⚡    │  │    💡    │ ← Long press here
│   │         │  │  ████   │            │
│   │Channel 1│  │Living Rm│            │
│   └─────────┘  └─────────┘            │
└─────────────────────────────────────────┘
```

### Step 2: Options Dialog Appears
```
┌─────────────────────────────────────────┐
│  Living Rm Options                  [×] │
├─────────────────────────────────────────┤
│                                         │
│  ✏️  Rename Channel                     │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  💡  Light                          ✓   │
│                                         │
│  ⚡  Switch                              │
│                                         │
├─────────────────────────────────────────┤
│                          [Close]        │
└─────────────────────────────────────────┘
```

**Dialog Elements:**
- **Title**: Shows channel name
- **Rename Channel**: Opens rename dialog
- **Light**: Configure as light (checkmark if selected)
- **Switch**: Configure as switch (checkmark if selected)
- **Close**: Dismiss dialog

## 3. Rename Channel Flow

### Step 1: Select "Rename Channel"
```
┌─────────────────────────────────────────┐
│  Rename Living Rm                   [×] │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Living Rm                    │   │
│  │                              ▌   │
│  └─────────────────────────────────┘   │
│                                         │
│  Character count: 9/50                  │
│                                         │
├─────────────────────────────────────────┤
│              [Cancel]    [Save]         │
└─────────────────────────────────────────┘
```

### Step 2: Success Message
```
┌─────────────────────────────────────────┐
│  ✓ Channel 2 renamed successfully       │
└─────────────────────────────────────────┘
```

## 4. Change Channel Type Flow

### Step 1: Select "Switch" (from Light)
```
User taps "Switch" option
              ↓
┌─────────────────────────────────────────┐
│  ✓ Channel 2 changed to Switch          │
└─────────────────────────────────────────┘
```

### Step 2: Icon Updates Immediately
```
Before:                    After:
┌─────────┐               ┌─────────┐
│    💡    │               │    ⚡    │
│         │      →        │         │
│Living Rm│               │Living Rm│
└─────────┘               └─────────┘
```

## 5. Enhanced Device Control Widget (Dashboard)

### List View with Icons
```
┌─────────────────────────────────────────┐
│  Smart Relay                            │
├─────────────────────────────────────────┤
│                                         │
│  💡  Living Room              [ON]  ●   │
│                                         │
│  ⚡  Channel 2                [OFF] ○   │
│                                         │
│  💡  Bedroom                  [ON]  ●   │
│                                         │
│  ⚡  Channel 4                [OFF] ○   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  [All ON]      [All OFF]        │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

**Icon Colors:**
- **ON state**: Bright primary color (blue/green)
- **OFF state**: Dim secondary color (gray)

## 6. State Transitions

### Channel OFF → ON
```
Before (OFF):              After (ON):
┌─────────┐               ┌─────────┐
│    💡    │               │    💡    │
│  (gray) │      →        │  (blue) │
│Living Rm│               │Living Rm│
└─────────┘               └─────────┘
```

### Channel ON → OFF
```
Before (ON):               After (OFF):
┌─────────┐               ┌─────────┐
│    💡    │               │    💡    │
│  (blue) │      →        │  (gray) │
│Living Rm│               │Living Rm│
└─────────┘               └─────────┘
```

## 7. Error States

### Network Error
```
┌─────────────────────────────────────────┐
│  ✗ Failed to update channel type:       │
│    Network error                        │
└─────────────────────────────────────────┘
```

### Permission Error
```
┌─────────────────────────────────────────┐
│  ✗ Failed to update channel type:       │
│    Device not found or access denied    │
└─────────────────────────────────────────┘
```

## 8. Color Scheme

### Light Theme (if applicable)
```
Primary Color:    #2196F3 (Blue)
Secondary Color:  #757575 (Gray)
Success Color:    #4CAF50 (Green)
Error Color:      #F44336 (Red)
Background:       #FFFFFF (White)
Card Background:  #F5F5F5 (Light Gray)
```

### Dark Theme (default)
```
Primary Color:    #64B5F6 (Light Blue)
Secondary Color:  #9E9E9E (Gray)
Success Color:    #81C784 (Light Green)
Error Color:      #E57373 (Light Red)
Background:       #121212 (Dark)
Card Background:  #1E1E1E (Dark Gray)
```

## 9. Responsive Layouts

### 2-Channel Device
```
┌─────────────────────────────────────────┐
│   ┌─────────┐  ┌─────────┐            │
│   │    💡    │  │    ⚡    │            │
│   │Living Rm│  │Kitchen  │            │
│   └─────────┘  └─────────┘            │
└─────────────────────────────────────────┘
```

### 4-Channel Device
```
┌─────────────────────────────────────────┐
│   ┌─────────┐  ┌─────────┐            │
│   │    💡    │  │    ⚡    │            │
│   │Living Rm│  │Kitchen  │            │
│   └─────────┘  └─────────┘            │
│                                         │
│   ┌─────────┐  ┌─────────┐            │
│   │    💡    │  │    ⚡    │            │
│   │Bedroom  │  │Bathroom │            │
│   └─────────┘  └─────────┘            │
└─────────────────────────────────────────┘
```

### 8-Channel Device
```
┌─────────────────────────────────────────┐
│   ┌────┐ ┌────┐ ┌────┐ ┌────┐         │
│   │ 💡 │ │ ⚡  │ │ 💡 │ │ ⚡  │         │
│   │Ch 1│ │Ch 2│ │Ch 3│ │Ch 4│         │
│   └────┘ └────┘ └────┘ └────┘         │
│                                         │
│   ┌────┐ ┌────┐ ┌────┐ ┌────┐         │
│   │ 💡 │ │ ⚡  │ │ 💡 │ │ ⚡  │         │
│   │Ch 5│ │Ch 6│ │Ch 7│ │Ch 8│         │
│   └────┘ └────┘ └────┘ └────┘         │
└─────────────────────────────────────────┘
```

## 10. Accessibility

### Screen Reader Announcements
```
"Channel 1, Living Room, Light, On"
"Channel 2, Kitchen, Switch, Off"
"Long press to open channel options"
"Channel type changed to Light"
```

### Touch Targets
- Minimum size: 48x48 dp
- Spacing: 8 dp between buttons
- Long press duration: 500ms

## 11. Animation & Feedback

### Icon Change Animation
```
Duration: 200ms
Easing: ease-in-out
Effect: Fade + Scale
```

### Success Message
```
Duration: 2 seconds
Position: Bottom of screen
Animation: Slide up + Fade in
```

### Dialog Transitions
```
Open: Fade in + Scale (300ms)
Close: Fade out + Scale (200ms)
```

## 12. Best Practices

### Icon Selection Guidelines
- **Use Light (💡) for:**
  - Ceiling lights
  - Lamps
  - LED strips
  - Any lighting fixture

- **Use Switch (⚡) for:**
  - Fans
  - Outlets
  - Appliances
  - General power switches

### Naming Conventions
- Keep names short (under 15 characters for grid view)
- Use descriptive names (e.g., "Living Room" not "LR")
- Avoid special characters
- Use title case for readability

## 13. Common UI Patterns

### Pattern 1: All Lights
```
┌─────────────────────────────────────────┐
│   ┌─────────┐  ┌─────────┐            │
│   │    💡    │  │    💡    │            │
│   │Living Rm│  │Bedroom  │            │
│   └─────────┘  └─────────┘            │
│                                         │
│   ┌─────────┐  ┌─────────┐            │
│   │    💡    │  │    💡    │            │
│   │Kitchen  │  │Bathroom │            │
│   └─────────┘  └─────────┘            │
└─────────────────────────────────────────┘
```

### Pattern 2: Mixed Configuration
```
┌─────────────────────────────────────────┐
│   ┌─────────┐  ┌─────────┐            │
│   │    💡    │  │    ⚡    │            │
│   │Lights   │  │Fan      │            │
│   └─────────┘  └─────────┘            │
│                                         │
│   ┌─────────┐  ┌─────────┐            │
│   │    ⚡    │  │    ⚡    │            │
│   │Outlet   │  │Heater   │            │
│   └─────────┘  └─────────┘            │
└─────────────────────────────────────────┘
```

## 14. Mobile vs Tablet Layout

### Mobile (Portrait)
- 2 columns for multi-channel
- Larger touch targets
- Full-width dialogs

### Tablet (Landscape)
- 3-4 columns for multi-channel
- Compact dialogs (centered)
- More information visible

## Summary

The channel type feature provides:
- ✅ Clear visual distinction between lights and switches
- ✅ Easy configuration via long-press
- ✅ Immediate visual feedback
- ✅ Persistent settings
- ✅ Consistent UI across all screens
- ✅ Accessible and responsive design
