# Timer Slot Management - Quick Reference

## Key Concepts

### Slots vs Timers
- **Slots**: Physical timer indices on HBOT device (1-16 total, Tasmota-compatible)
- **Timers**: User-created timer configurations
- **Important**: One "All Channels" timer = Multiple slots!

### Slot Usage
```
Single Channel Timer = 1 slot
All Channels Timer (4ch device) = 4 slots
All Channels Timer (8ch device) = 8 slots
```

## Quick Examples

### 8-Channel Device
```
✅ Can create: 2 "All Channels" timers (2 × 8 = 16 slots)
✅ Can create: 16 single-channel timers (16 × 1 = 16 slots)
✅ Can create: 1 "All Channels" + 8 single-channel (8 + 8 = 16 slots)
❌ Cannot create: 3 "All Channels" timers (3 × 8 = 24 slots > 16!)
```

### 4-Channel Device
```
✅ Can create: 4 "All Channels" timers (4 × 4 = 16 slots)
✅ Can create: 16 single-channel timers (16 × 1 = 16 slots)
✅ Can create: 2 "All Channels" + 8 single-channel (8 + 8 = 16 slots)
❌ Cannot create: 5 "All Channels" timers (5 × 4 = 20 slots > 16!)
```

## UI Indicators

### App Bar
```
"12/16 slots used • 3 timers"
 ↑              ↑
 Actual slots   Timer count
```

### Timer Card
```
Timer 1: 07:00 AM
All Channels • Every day
Slots 1-8  ← Shows device slots occupied
```

### Deletion Message
```
"Freed 8 slots (8/16 used)"
       ↑        ↑
       Freed    Remaining
```

## Common Scenarios

### Scenario: "Why can't I add another timer?"
**Check**: Slot usage, not timer count!
```
Example: 8-channel device
- 2 "All Channels" timers = 16 slots used
- Shows: "16/16 slots used • 2 timers"
- Result: Cannot add more (even though only 2 timers)
```

### Scenario: "I deleted a timer but still can't add one"
**Reason**: Need contiguous slots!
```
Example: 8-channel device
Slots: [1-8: Timer1][9: Timer2][10-16: Free]
       ↑ 8 slots    ↑ 1 slot   ↑ 7 slots free

Try to add "All Channels" timer (needs 8 contiguous slots):
❌ Cannot fit! Largest contiguous block is 7 slots (10-16)

Solution: Delete Timer1 to free slots 1-8
```

### Scenario: "How do I maximize my timers?"
**Strategy**: Use single-channel timers when possible!
```
8-channel device:
Option A: 2 "All Channels" timers = 16 slots (2 timers total)
Option B: 16 single-channel timers = 16 slots (16 timers total!)

Recommendation: Use "All Channels" only when you need all channels
to do the same action at the same time.
```

## Error Messages Explained

### "Not enough timer slots available"
```
Meaning: Device has 16 slots total, not enough free
Solution: Delete existing timers or use Scene Control
```

### "Need X contiguous slots"
```
Meaning: Slots are fragmented, need X slots in a row
Example: Need 8 slots, but only have [3 free][occupied][4 free]
Solution: Delete timers to create larger contiguous block
```

### "Currently occupied: X/16 slots"
```
Meaning: X device slots are in use
Note: This is NOT the same as timer count!
```

## Best Practices

### 1. Plan Your Timers
```
Before creating timers, calculate slot usage:
- 4-channel device: Each "All Channels" = 4 slots
- 8-channel device: Each "All Channels" = 8 slots
```

### 2. Use Single-Channel When Possible
```
✅ Good: 4 single-channel timers = 4 slots
❌ Wasteful: 1 "All Channels" timer = 8 slots (if only need 1 channel)
```

### 3. Group Similar Actions
```
If all channels need same action at same time:
✅ Use "All Channels" timer (cleaner, easier to manage)

If channels need different actions:
✅ Use separate single-channel timers
```

### 4. Monitor Slot Usage
```
Always check app bar: "X/16 slots used"
- Green text: Plenty of space
- Orange text: At limit (16/16)
```

### 5. Consider Scene Control
```
When you need more than 16 slots worth of timers:
→ Use Scene Control for advanced automation
→ Unlimited timers, more features, cloud-based
```

## Troubleshooting

### Problem: Can't add timer, but shows "8/16 slots used"
**Check**: How many slots does your new timer need?
```
Example: 8-channel device, want "All Channels" timer
- Current: 8/16 slots used
- Need: 8 contiguous slots
- Available: Maybe fragmented (e.g., [4 free][occupied][4 free])
- Solution: Delete a timer to create 8 contiguous slots
```

### Problem: Deleted timer but slot count didn't change
**Reason**: Timer was disabled, not deleted
```
Check: Did you confirm deletion in the dialog?
- Disable: Timer stays in list (grayed out), slots still occupied
- Delete: Timer removed from list, slots freed
```

### Problem: Timer shows "Slots 1-8" but I only selected Channel 1
**Reason**: You selected "All Channels" by mistake
```
Solution: Edit timer, change from "All Channels" to "CH 1"
Result: Will only occupy 1 slot instead of 8
```

## Quick Decision Tree

```
Want to add a timer?
│
├─ Check: "X/16 slots used" in app bar
│
├─ Single channel timer?
│  ├─ Need 1 slot
│  └─ If X < 16 → ✅ Can add
│
└─ All channels timer?
   ├─ Need N slots (N = number of channels)
   ├─ If X + N ≤ 16 → Check contiguity
   │  ├─ Have N contiguous free slots? → ✅ Can add
   │  └─ Slots fragmented? → ❌ Delete timer to defragment
   └─ If X + N > 16 → ❌ Delete timers or use Scene Control
```

## Summary

**Remember**:
1. 16 slots total on device (not 16 timers!)
2. "All Channels" = N slots (N = channel count)
3. Single channel = 1 slot
4. Need contiguous slots for multi-slot timers
5. Check "X/16 slots used" in app bar
6. Use Scene Control when you need more

**Pro Tip**: Prefer single-channel timers to maximize timer count!
