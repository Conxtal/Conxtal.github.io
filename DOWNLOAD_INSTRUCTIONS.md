# 📥 DOWNLOAD INSTRUCTIONS

## 🎯 What You're Getting

A complete, refactored combat system with:
- ✅ Aerial M1 combos
- ✅ Combo inheritance system
- ✅ Hold vs Tap spacebar mechanics
- ✅ Clean, modular code
- ✅ All improvements from the refactoring

---

## 📦 Files to Download

### **Main Game File:**
```
bggame_refactored.rbxlx
```
This is your updated game file with 25 scripts already refactored!

### **New Modules to Add Manually:**

You'll need to add these 5 new modules in Roblox Studio:

**Location: ReplicatedStorage/Combat/Modules/**
1. `AerialComboSystem.lua` - from `scripts/shared/AerialComboSystem.lua`
2. `InputBuffer.lua` - from `scripts/shared/InputBuffer.lua`

**Location: ServerScriptService/Combat/Handlers/**
3. `UptiltHandler.lua` - from `scripts/server/UptiltHandler.lua`
4. `AerialHandler.lua` - from `scripts/server/AerialHandler.lua`

---

## 🚀 Quick Setup (5 minutes)

### **Step 1: Download Files**
Download from GitHub repository:
```
https://github.com/Conxtal/Conxtal.github.io/tree/claude/decipher-rbxlx-codebases-8RMNo
```

Or download these specific files:
- `bggame_refactored.rbxlx`
- `scripts/shared/AerialComboSystem.lua`
- `scripts/shared/InputBuffer.lua`
- `scripts/server/UptiltHandler.lua`
- `scripts/server/AerialHandler.lua`

### **Step 2: Import to Roblox Studio**
1. Open Roblox Studio
2. File → Open → Select `bggame_refactored.rbxlx`
3. Wait for it to load (25 scripts already updated!)

### **Step 3: Add New Modules**

**A. Add AerialComboSystem:**
1. In Explorer: `ReplicatedStorage` → `Combat` → `Modules`
2. Right-click `Modules` → Insert Object → ModuleScript
3. Rename to `AerialComboSystem`
4. Open the script, paste content from `scripts/shared/AerialComboSystem.lua`

**B. Add InputBuffer:**
1. Still in `Modules` folder
2. Right-click → Insert Object → ModuleScript
3. Rename to `InputBuffer`
4. Paste content from `scripts/shared/InputBuffer.lua`

**C. Add UptiltHandler:**
1. In Explorer: `ServerScriptService` → `Combat` → `Handlers`
2. Right-click `Handlers` → Insert Object → ModuleScript
3. Rename to `UptiltHandler`
4. Paste content from `scripts/server/UptiltHandler.lua`

**D. Add AerialHandler:**
1. Still in `Handlers` folder
2. Right-click → Insert Object → ModuleScript
3. Rename to `AerialHandler`
4. Paste content from `scripts/server/AerialHandler.lua`

### **Step 4: Update InitServer**

The `InitServer` script is already updated to require these modules!
Just verify it has these lines:
```lua
local AerialCombo = require(CombatFolder.Modules.AerialComboSystem)
```

### **Step 5: Test!**
1. Press F5 to play test
2. Try the new controls:
   - M1 → M1 → Space (uptilt)
   - Click in air for aerial M1s
   - Hold C in air for knockback
   - Tap C in air for slam
3. Check console for any errors

---

## ✅ Verification Checklist

After setup, verify these work:

- [ ] Game loads without errors
- [ ] M1 combos work on ground
- [ ] Space key launches enemies (uptilt)
- [ ] Can attack in air after uptilt
- [ ] Hold C = knockback attack
- [ ] Tap C = down slam
- [ ] Animations play smoothly
- [ ] No console errors

---

## 📁 Repository Structure

```
Your GitHub Repository:
├── bggame_refactored.rbxlx          ← Main file (25 scripts updated)
├── scripts/
│   ├── shared/
│   │   ├── AerialComboSystem.lua    ← NEW MODULE
│   │   ├── InputBuffer.lua          ← NEW MODULE
│   │   ├── AttackHandler.lua        ← REFACTORED
│   │   └── ...
│   └── server/
│       ├── UptiltHandler.lua        ← NEW MODULE
│       ├── AerialHandler.lua        ← NEW MODULE
│       └── ...
├── AERIAL_COMBAT_GUIDE.md           ← Complete feature guide
├── SETUP_GUIDE.md                   ← General setup guide
└── REFACTORING_SUMMARY.md           ← What was changed
```

---

## 🎮 Controls Reference

**Ground Combat:**
- Click - M1 combo (4 hits)
- Space - Uptilt launcher
- Q - Dash
- F - Block

**Aerial Combat:**
- Click - Air M1 combos
- Hold C (0.25s+) - Knockback attack
- Tap C - Down slam
- Q - Air dash

---

## ❓ Troubleshooting

**"Module not found" error:**
- Make sure you added all 4 new modules in the correct locations

**"AerialCombo is nil" error:**
- Check that AerialComboSystem is in `ReplicatedStorage/Combat/Modules/`

**Uptilt not working:**
- Verify UptiltHandler is in `ServerScriptService/Combat/Handlers/`

**Aerial attacks not working:**
- Check that AerialHandler is in the Handlers folder
- Make sure Aerial remote is created (InitServer does this automatically)

---

## 📞 Need Help?

1. Check `AERIAL_COMBAT_GUIDE.md` for feature explanations
2. Check console output for specific errors
3. Verify all modules are in correct locations
4. Make sure file names match exactly (case-sensitive!)

---

## 🎉 You're Done!

Once setup is complete, you'll have:
- ✅ Professional-grade aerial combat
- ✅ Smart combo system
- ✅ Hold vs Tap mechanics
- ✅ Clean, maintainable code

**Enjoy your refactored combat system!** 🚀
