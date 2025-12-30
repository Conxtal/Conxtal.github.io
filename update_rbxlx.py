#!/usr/bin/env python3
"""
update_rbxlx.py
Updates the bg game.rbxlx file with refactored scripts

NOTE: This script updates EXISTING scripts only.
NEW scripts (UptiltHandler, AerialHandler) need to be added manually in Roblox Studio.
"""

import xml.etree.ElementTree as ET
import os

print("=" * 60)
print("RBXLX Update Script")
print("=" * 60)

# Parse the rbxlx file
print("\n[1/4] Loading bggame.rbxlx...")
tree = ET.parse('bggame.rbxlx')
root = tree.getroot()

# Map of script names to file paths
SCRIPT_MAPPINGS = {
    # Client scripts
    'InitClient': 'scripts/client/InitClient.lua',
    'Animate': 'scripts/client/Animate_1.lua',  # Use the larger one

    # Server scripts
    'InitServer': 'scripts/server/InitServer.lua',

    # Shared/Module scripts
    'CombatClient': 'scripts/shared/CombatClient.lua',
    'InputHandler': 'scripts/shared/InputHandler.lua',
    'AnimationHandler': 'scripts/shared/AnimationHandler.lua',
    'VFXHandler': 'scripts/shared/VFXHandler.lua',
    'LockOn': 'scripts/shared/LockOn.lua',
    'CombatLockClient': 'scripts/shared/CombatLockClient.lua',
    'Config': 'scripts/shared/Config.lua',
    'StateManager': 'scripts/shared/StateManager.lua',
    'CooldownManager': 'scripts/shared/CooldownManager.lua',
    'HitboxHandler': 'scripts/shared/HitboxHandler.lua',
    'CharacterRegistry': 'scripts/shared/CharacterRegistry.lua',
    'BlockHandler': 'scripts/shared/BlockHandler.lua',
    'DashHandler': 'scripts/shared/DashHandler.lua',
    'AbilityHandler': 'scripts/shared/AbilityHandler.lua',
    'PassiveHandler': 'scripts/shared/PassiveHandler.lua',
    'AttackHandler': 'scripts/shared/AttackHandler.lua',
    'CombatLock': 'scripts/shared/CombatLock.lua',

    # Characters
    'Arthur': 'scripts/characters/Arthur.lua',
    'ArthurVFX': 'scripts/characters/ArthurVFX.lua',

    # Movement/Input
    'MovementHandler': 'scripts/shared/MovementHandler.lua',
    'InputTracker': 'scripts/shared/InputTracker.lua',
}

print(f"[2/4] Found {len(SCRIPT_MAPPINGS)} scripts to update")

# Update scripts
updated_count = 0
skipped_count = 0

print("[3/4] Updating script sources...")

for item in root.iter('Item'):
    item_class = item.get('class')
    if item_class in ['Script', 'LocalScript', 'ModuleScript']:
        # Get the script name
        name_elem = item.find('.//string[@name="Name"]')
        if name_elem is None or name_elem.text is None:
            continue

        script_name = name_elem.text

        if script_name in SCRIPT_MAPPINGS:
            file_path = SCRIPT_MAPPINGS[script_name]

            if os.path.exists(file_path):
                # Read the new source code
                with open(file_path, 'r', encoding='utf-8') as f:
                    new_source = f.read()

                # Find the Source element
                source_elem = item.find('.//ProtectedString[@name="Source"]')
                if source_elem is not None:
                    source_elem.text = new_source
                    updated_count += 1
                    print(f"  ✅ Updated: {script_name}")
                else:
                    print(f"  ⚠️  Warning: No Source element for {script_name}")
                    skipped_count += 1
            else:
                print(f"  ⚠️  Warning: File not found: {file_path}")
                skipped_count += 1

print(f"\n[4/4] Saving updated rbxlx file...")
tree.write('bggame_refactored.rbxlx', encoding='utf-8', xml_declaration=True)

print("\n" + "=" * 60)
print("✅ RBXLX UPDATE COMPLETE!")
print("=" * 60)
print(f"\nUpdated scripts: {updated_count}")
print(f"Skipped: {skipped_count}")
print(f"\nOutput file: bggame_refactored.rbxlx")

print("\n⚠️  IMPORTANT NOTES:")
print("=" * 60)
print("1. NEW HANDLERS NOT ADDED (must add manually in Roblox Studio):")
print("   - UptiltHandler (scripts/server/UptiltHandler.lua)")
print("   - AerialHandler (scripts/server/AerialHandler.lua)")
print("\n2. To add these in Roblox Studio:")
print("   a. Open bggame_refactored.rbxlx")
print("   b. Add ModuleScript to ServerScriptService/Combat/Handlers")
print("   c. Rename to 'UptiltHandler' and paste code from file")
print("   d. Repeat for 'AerialHandler'")
print("\n3. Test all functionality after importing!")
print("=" * 60)
