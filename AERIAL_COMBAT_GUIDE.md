# 🌪️ Aerial Combat System - Complete Guide

## 🎯 What's New

Your combat system now has a **complete aerial combat overhaul** with:
- ✅ Aerial M1 combos after uptilt
- ✅ Combo inheritance system (smarter air attacks)
- ✅ Hold vs Tap mechanics for spacebar
- ✅ Mid-air knockback attacks
- ✅ Much cleaner, modular code

---

## 🎮 How It Works

### **1. Ground Combat → Uptilt → Air Combat**

```
Ground M1 Combo → Uptilt (Space) → Aerial M1 Combos → Finish
```

### **2. Combo Inheritance System**

The number of air hits you get depends on when you uptilt:

| Uptilt At | Air Hits Remaining | Total Combo |
|-----------|-------------------|-------------|
| **M1-1** (1st hit) | 3 air M1s | 1 + 3 = 4 hits total |
| **M1-2** (2nd hit) | 2 air M1s | 2 + 2 = 4 hits total |
| **M1-3** (3rd hit) | ❌ Can't uptilt | Locked out |
| **M1-4** (4th hit) | ❌ Can't uptilt | Locked out |

**Example Flow:**
```
Click → Click → Space (uptilt at M1-2)
↓
You're now airborne with 2 air M1s available
↓
Click → Click (aerial M1-1, M1-2)
↓
Combo complete!
```

---

## ⌨️ New Controls & Mechanics

### **Spacebar Mechanics (Context-Sensitive)**

| Situation | Action | Result |
|-----------|--------|--------|
| **On ground** | Tap Space | Uptilt (launcher) |
| **In air + Hold C (0.25s+)** | Hold → Press C | **Knockback** (launches enemy mid-air) |
| **In air + Tap C** | Quick C press | **Down Slam** (AOE ground pound) |

### **Full Control Scheme**

```
Ground Combat:
  Click      - M1 combo (4 hits max)
  Space      - Uptilt launcher (only before M1-3)
  Q          - Dash
  F          - Block

Aerial Combat:
  Click      - Air M1 combos (inherits from ground)
  Hold C     - Knockback attack (sends enemy flying)
  Tap C      - Down slam (AOE damage on land)
  Q          - Air dash
```

---

## 📊 Attack Data Breakdown

### **Uptilt (Launcher)**
```lua
Damage: 12
LaunchVelocity: 22 (vertical)
ForwardPush: 4 (horizontal)
Hitstun: 0.28s
StaminaCost: 10
Can use: Before M1-3 only
```

### **Aerial M1 Combos**
```lua
Air Hit 1:
  Damage: 9
  Knockback: 50 (keeps in air)
  Lift: 2 (slight upward)

Air Hit 2:
  Damage: 10
  Knockback: 55
  Lift: 1

Air Hit 3 (Finisher):
  Damage: 14
  Knockback: 100 (sends flying)
  Lift: 5 (big launch)
```

### **Down Slam (Tap C)**
```lua
Damage: 18 (base)
SlamForce: 150 (downward speed)
Radius: 8 studs (AOE)
Knockback: 80 (radial from impact)
Distance Falloff: Yes (closer = more damage)
```

### **Aerial Knockback (Hold C)**
```lua
Damage: 15
KnockbackForce: 120 (horizontal)
Lift: 10 (vertical)
Hitstun: 0.35s
Works: Mid-air only
```

---

## 🎭 Advanced Techniques

### **1. Maximum Damage Combo**
```
M1 → M1 → Uptilt → Air M1 → Air M1 → Hold C (knockback)
= 6 hits total, keeps pressure
```

### **2. Quick Launcher**
```
M1 → Uptilt → Air M1 → Tap C (slam)
= Fast AOE damage
```

### **3. Juggle Combo**
```
M1 → Uptilt → Air M1 → Hold C (knockback) → They fly far
= Best for spacing
```

### **4. Anti-Air Punish**
```
Enemy jumps → Uptilt → Air M1 combos → Down slam
= Punish aerial enemies
```

---

## 🏗️ New Module Architecture

### **New Modules Created:**

#### **AerialComboSystem.lua**
- Manages all aerial combat state
- Tracks combo inheritance
- Handles spacebar hold detection
- Clean, focused responsibility

#### **InputBuffer.lua**
- Better input handling
- Hold vs tap detection
- Input queuing for combos
- Prevents input loss

### **Refactored Handlers:**

#### **AttackHandler (V2)**
- Supports both ground AND aerial M1s
- Unified attack execution
- Cleaner hit application
- Better state management

#### **UptiltHandler (V2)**
- Starts aerial combat state
- Tracks ground combo for inheritance
- Only allows uptilt before M1-3
- Cleaner, more focused

#### **AerialHandler (V2)**
- Separate logic for hold vs tap
- Knockback version (hold)
- Slam version (tap)
- Much cleaner than before

---

## 📂 File Structure (Clean!)

```
scripts/
├── shared/
│   ├── AerialComboSystem.lua      ← NEW: Air combat management
│   ├── InputBuffer.lua             ← NEW: Better input handling
│   ├── AttackHandler.lua           ← REFACTORED: Ground + Air M1s
│   ├── AnimationHandler.lua        ← UPDATED: Air M1 animations
│   ├── InputHandler.lua            ← UPDATED: Hold detection
│   └── CombatClient.lua            ← UPDATED: Air M1 states
│
├── server/
│   ├── UptiltHandler.lua           ← REFACTORED: Starts aerial state
│   ├── AerialHandler.lua           ← REFACTORED: Hold vs Tap
│   └── InitServer.lua              ← UPDATED: Loads new modules
│
├── characters/
│   └── Arthur.lua                  ← UPDATED: AerialM1 data added
│
└── *_OLD.lua files                 ← Backups of old versions
```

---

## 🎯 What Makes This Better

### **Code Quality Improvements:**

**BEFORE (Old System):**
```lua
❌ Spaghetti code all over the place
❌ Uptilt and Aerial were incomplete/broken
❌ No aerial combo system at all
❌ Hard to understand where things go
❌ Everything mixed together
```

**AFTER (New System):**
```lua
✅ Clean, modular architecture
✅ Each module has ONE job
✅ Complete aerial combat system
✅ Easy to find and modify code
✅ Proper separation of concerns
```

### **Feature Improvements:**

| Feature | Before | After |
|---------|--------|-------|
| Aerial M1s | ❌ None | ✅ Full system |
| Combo inheritance | ❌ None | ✅ Smart scaling |
| Hold vs Tap | ❌ None | ✅ Implemented |
| Code organization | ❌ Messy | ✅ Clean modules |
| Mid-air attacks | ❌ None | ✅ Knockback option |

---

## 🧪 Testing Checklist

Test these scenarios to verify everything works:

### **Ground Combat**
- [ ] M1 combo (4 hits) works smoothly
- [ ] Can uptilt at M1-1 (get 3 air hits)
- [ ] Can uptilt at M1-2 (get 2 air hits)
- [ ] Cannot uptilt at M1-3 or M1-4

### **Aerial Combat**
- [ ] After uptilt, click for aerial M1s
- [ ] Air M1 count matches ground combo
- [ ] Animations play smoothly
- [ ] Combos keep enemy in air

### **Spacebar Mechanics**
- [ ] Tap C in air = down slam with AOE
- [ ] Hold C (0.25s+) in air = knockback
- [ ] Knockback sends enemy flying horizontally
- [ ] Down slam has radial damage

### **Edge Cases**
- [ ] Aerial state ends after air combos finish
- [ ] Can't use aerial attacks on ground
- [ ] Stamina drains properly
- [ ] Cooldowns work correctly

---

## 💡 Tips for Players

1. **Save Uptilt:** Don't uptilt on M1-1 if you want max ground damage first
2. **Use Hold C:** For spacing and sending enemies away
3. **Use Tap C:** For AOE damage against groups
4. **Combo Variety:** Mix up uptilt timings for different situations
5. **Air Mobility:** Dash works in air too for repositioning

---

## 🔧 Customization

Want to tweak values? Edit `Arthur.lua`:

### **Change Air Combo Count**
```lua
-- In AerialComboSystem.StartAerialState()
local maxAirHits = 4 - groundCombo  -- Change the math here
```

### **Adjust Hold Threshold**
```lua
-- In InputHandler.lua
local HOLD_THRESHOLD = 0.25  -- Make it easier/harder to hold
```

### **Modify Aerial Damage**
```lua
-- In Arthur.lua → AerialM1 section
Hits = {
    {damage = 9, ...},    -- Change these values
    {damage = 10, ...},
    {damage = 14, ...},
}
```

---

## 🐛 Known Limitations

1. **Animation Placeholders:** Some aerial animations use ID 0 (need real animations)
2. **VFX Stubs:** VFXHandler.OnAirM1() needs implementation
3. **Tuning:** Damage/knockback values may need balancing

---

## 📝 Summary

**You now have:**
- ✅ Complete aerial combat system
- ✅ Smart combo inheritance
- ✅ Hold vs Tap spacebar mechanics
- ✅ Mid-air knockback attacks
- ✅ AOE ground slams
- ✅ Much cleaner, maintainable code
- ✅ Proper module organization
- ✅ Easy to expand and customize

**The code went from sloppy spaghetti to clean, professional architecture!**

---

## 🚀 Next Steps

1. Add proper aerial M1 animations (replace rbxassetid://0)
2. Implement VFXHandler.OnAirM1() for air hit effects
3. Tune damage/knockback values based on playtesting
4. Add more characters with different aerial styles
5. Expand with wall jumps, double jumps, etc.

**Enjoy your professional-grade aerial combat system!** 🎮⚔️
