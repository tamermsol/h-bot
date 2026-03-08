# Transparency Guide - Quick Reference

## Current Settings

### Overlay (Background Dimming)
```dart
overlayOpacity: 0.3  // 30% dark overlay
```
- Lower = More background visible
- Higher = Better text readability

### UI Elements
```dart
alpha: 0.7  // 70% opacity (30% transparent)
```
- Lower = More transparent
- Higher = More solid

## Visual Effect

```
Background Image (100% visible)
    ↓
Dark Overlay (30% opacity)
    ↓
UI Elements (70% opacity)
    ↓
Text & Icons (100% opacity)
```

## Adjustment Guide

### Want More Background?
```dart
// Make overlay lighter
overlayOpacity: 0.2  // 20% overlay

// Make cards more transparent
alpha: 0.6  // 60% opacity
```

### Want Better Readability?
```dart
// Make overlay darker
overlayOpacity: 0.4  // 40% overlay

// Make cards more solid
alpha: 0.8  // 80% opacity
```

### Want Glass Effect?
```dart
// Light overlay
overlayOpacity: 0.25

// Very transparent cards
alpha: 0.5
```

## Examples

### Current (Balanced)
- Overlay: 30%
- Cards: 70%
- Result: Good balance

### Showcase Mode (More Background)
- Overlay: 20%
- Cards: 60%
- Result: Background prominent

### Reading Mode (Better Contrast)
- Overlay: 40%
- Cards: 80%
- Result: Easier to read

### Glass Mode (Modern Look)
- Overlay: 25%
- Cards: 50%
- Result: Very modern

## Quick Test

1. Select a colorful background
2. Check if text is readable
3. Adjust overlay if needed
4. Adjust card opacity if needed

## Recommendations

### Bright Backgrounds
- Use higher overlay (0.4)
- Use higher card opacity (0.8)

### Dark Backgrounds
- Use lower overlay (0.2)
- Use lower card opacity (0.6)

### Colorful Backgrounds
- Use medium overlay (0.3)
- Use medium card opacity (0.7)

## Summary

Current settings (0.3 overlay, 0.7 cards) provide:
- ✅ Good background visibility
- ✅ Readable text
- ✅ Modern glass effect
- ✅ Balanced appearance

Adjust based on your background images and preferences!
