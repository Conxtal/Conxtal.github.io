# 🚀 Setup Guide - Refactored Combat System

## Quick Start

### Option 1: Use the Refactored RBXLX (Recommended)

1. **Import the file:**
   ```
   Open Roblox Studio → File → Open → bggame_refactored.rbxlx
   ```

2. **Add the new handlers** (2 new scripts):

   **A. UptiltHandler**
   - Location: `ServerScriptService/Combat/Handlers/`
   - Type: ModuleScript
   - Name: `UptiltHandler`
   - Source: Copy from `scripts/server/UptiltHandler.lua`

   **B. AerialHandler**
   - Location: `ServerScriptService/Combat/Handlers/`
   - Type: ModuleScript
   - Name: `AerialHandler`
   - Source: Copy from `scripts/server/AerialHandler.lua`

3. **Test it:**
   - Play solo
   - Try all controls (see below)
   - Check for smooth animations
   - Test combos and aerial attacks

---

## 🎮 Controls

| Action | Key | Description |
|--------|-----|-------------|
| **Attack** | Left Click | 4-hit combo chain |
| **Uptilt** | Space | Launch attack (sends enemies airborne) |
| **Aerial** | C | Down slam (only while airborne) |
| **Dash** | Q | Quick dash with i-frames |
| **Block** | F | Block/deflect attacks |
| **Abilities** | 1-4 | Character abilities |

---

## 📋 What's New

### ✅ Fixed Issues
- Uptilt attack now works (was completely missing)
- Aerial/down slam attack implemented (was completely missing)
- Smooth animation transitions (no more jarring cuts)
- Server no longer crashes on startup
- All module paths fixed

### ✅ New Features
- **Aerial Attack:** Plunge attack with AOE damage
- **Smooth Animations:** Genshin Impact-style blending
- **Animation Queueing:** Buffer inputs during attacks
- **Root Motion:** Smooth character movement
- **State Management:** Proper animation state tracking

---

## 🔧 Folder Structure

```
ReplicatedStorage/
└── Combat/
    ├── Config
    ├── Modules/
    │   ├── StateManager
    │   ├── CooldownManager
    │   ├── HitboxHandler
    │   └── LockOn
    │
    ├── Handlers/  (Client)
    │   ├── InputHandler
    │   ├── AnimationHandler (ENHANCED ✨)
    │   ├── VFXHandler
    │   └── CombatLockClient
    │
    ├── Characters/
    │   ├── Arthur (UPDATED with Aerial data ✨)
    │   └── ArthurVFX
    │
    └── ...

ServerScriptService/
└── Combat/
    ├── InitServer (FIXED ✨)
    │
    └── Handlers/
        ├── CharacterRegistry
        ├── AttackHandler
        ├── UptiltHandler (NEW ✨)
        ├── AerialHandler (NEW ✨)
        ├── BlockHandler
        ├── DashHandler
        ├── AbilityHandler
        ├── PassiveHandler
        └── CombatLock
```

---

## 🎯 Testing Checklist

After setup, test these scenarios:

### Basic Combat
- [ ] M1 combo (4 hits) flows smoothly
- [ ] Animations blend without jarring cuts
- [ ] Final hit launches enemy

### Uptilt Attack
- [ ] Space key launches enemy upward
- [ ] Can't use after 3rd/4th M1 hit
- [ ] Enemies enter airborne state

### Aerial Attack
- [ ] C key only works when airborne
- [ ] Slams down with force
- [ ] AOE damage on impact
- [ ] Enemies knocked back radially

### Movement
- [ ] Dash cancels attacks
- [ ] Dash has i-frames
- [ ] Block can cancel recovery

### Visual Polish
- [ ] Attack animations fade in smoothly
- [ ] Return to idle is smooth
- [ ] Combos flow like Genshin Impact
- [ ] No animation stuttering

---

## ⚠️ Common Issues

### Issue: "UptiltHandler not found"
**Fix:** Make sure you added UptiltHandler ModuleScript to Handlers folder

### Issue: "Aerial remote not found"
**Fix:** InitServer creates this automatically, just restart the server

### Issue: Animations still look choppy
**Fix:** Make sure you're using the NEW AnimationHandler (Enhanced version)

### Issue: Server crashes on start
**Fix:** Check that all handler modules are in the correct folders

---

## 📊 Performance Notes

The refactored system is **more performant** than before:
- Animation caching reduces memory usage
- Smart state management prevents redundant checks
- Proper cleanup prevents memory leaks
- Optimized transition times

---

## 🎨 Customization

### Adjust Animation Transition Times
Edit `AnimationHandler.lua` lines 20-30:
```lua
local TRANSITION_TIMES = {
    Idle_Attack = 0.08,      -- Make faster/slower
    Attack_Attack = 0.05,    -- Combo speed
    Attack_Idle = 0.15,      -- Return speed
}
```

### Modify Aerial Damage
Edit `Arthur.lua` Aerial section:
```lua
Aerial = {
    Damage = 18,        -- Change damage
    Radius = 8,         -- Change AOE size
    StaminaCost = 15,   -- Change cost
}
```

### Add New Attacks
1. Add attack data to character file
2. Create handler following UptiltHandler pattern
3. Add keybind in InputHandler
4. Add animation in AnimationHandler
5. Add state handling in CombatClient

---

## 📞 Support

Issues? Check:
1. **CODEBASE_ANALYSIS.md** - Detailed architecture
2. **REFACTORING_SUMMARY.md** - All changes made
3. Script folders in `/scripts/` - Source code reference

---

## 🎉 You're All Set!

Your combat system is now:
- ✅ Fully functional
- ✅ Smooth and polished
- ✅ Easy to maintain
- ✅ Ready to expand

**Enjoy your Genshin/Sifu/Sekiro-style combat!** ⚔️
