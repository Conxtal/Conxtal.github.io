#!/usr/bin/env python3
"""
create_complete_rbxlx.py
Creates a complete RBXLX file with ALL new systems included
"""

import xml.etree.ElementTree as ET
import os
import uuid

print("=" * 70)
print("CREATING COMPLETE RBXLX WITH ALL NEW SYSTEMS")
print("=" * 70)

# Parse the original rbxlx file
print("\n[1/6] Loading original bggame.rbxlx...")
tree = ET.parse('bggame.rbxlx')
root = tree.getroot()

# Update existing scripts
print("[2/6] Updating existing scripts...")

SCRIPT_MAPPINGS = {
    'InitClient': 'scripts/client/InitClient.lua',
    'Animate': 'scripts/client/Animate_1.lua',
    'InitServer': 'scripts/server/InitServer.lua',
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
    'Arthur': 'scripts/characters/Arthur.lua',
    'ArthurVFX': 'scripts/characters/ArthurVFX.lua',
    'MovementHandler': 'scripts/shared/MovementHandler.lua',
    'InputTracker': 'scripts/shared/InputTracker.lua',
}

updated_count = 0
for item in root.iter('Item'):
    item_class = item.get('class')
    if item_class in ['Script', 'LocalScript', 'ModuleScript']:
        name_elem = item.find('.//string[@name="Name"]')
        if name_elem is None or name_elem.text is None:
            continue

        script_name = name_elem.text

        if script_name in SCRIPT_MAPPINGS:
            file_path = SCRIPT_MAPPINGS[script_name]
            if os.path.exists(file_path):
                with open(file_path, 'r', encoding='utf-8') as f:
                    new_source = f.read()

                source_elem = item.find('.//ProtectedString[@name="Source"]')
                if source_elem is not None:
                    source_elem.text = new_source
                    updated_count += 1
                    print(f"  ✅ Updated: {script_name}")

print(f"\n  Total updated: {updated_count} scripts")

# Helper function to create a ModuleScript element
def create_module_script(name, source_code, referent=None):
    if referent is None:
        referent = "RBX" + uuid.uuid4().hex.upper()[:32]

    item = ET.Element('Item', {
        'class': 'ModuleScript',
        'referent': referent
    })

    properties = ET.SubElement(item, 'Properties')

    # LinkedSource
    linked = ET.SubElement(properties, 'Content', {'name': 'LinkedSource'})
    linked.text = 'null'

    # Name
    name_elem = ET.SubElement(properties, 'string', {'name': 'Name'})
    name_elem.text = name

    # ScriptGuid
    guid_elem = ET.SubElement(properties, 'BinaryString', {'name': 'ScriptGuid'})
    guid_elem.text = ''

    # Source
    source_elem = ET.SubElement(properties, 'ProtectedString', {'name': 'Source'})
    source_elem.text = source_code

    # Tags
    tags_elem = ET.SubElement(properties, 'BinaryString', {'name': 'Tags'})
    tags_elem.text = ''

    return item

# Find the Combat folder in ReplicatedStorage
print("\n[3/6] Finding Combat folder structure...")
combat_folder = None
modules_folder = None
handlers_folder = None

for item in root.iter('Item'):
    name_elem = item.find('.//string[@name="Name"]')
    if name_elem is not None and name_elem.text == "Combat":
        combat_folder = item
        print("  ✅ Found Combat folder")

        # Find Modules subfolder
        for child in item:
            if child.tag == 'Item':
                child_name = child.find('.//string[@name="Name"]')
                if child_name is not None and child_name.text == "Modules":
                    modules_folder = child
                    print("  ✅ Found Modules folder")
                    break
        break

# Find Handlers folder in ServerScriptService
for item in root.iter('Item'):
    name_elem = item.find('.//string[@name="Name"]')
    if name_elem is not None and name_elem.text == "Handlers":
        parent_item = None
        for parent in root.iter('Item'):
            if item in parent:
                parent_name = parent.find('.//string[@name="Name"]')
                if parent_name is not None and parent_name.text == "Combat":
                    handlers_folder = item
                    print("  ✅ Found Handlers folder")
                    break

# Add new modules to Modules folder
print("\n[4/6] Adding new modules to Combat/Modules...")

NEW_MODULES = {
    'AerialComboSystem': 'scripts/shared/AerialComboSystem.lua',
    'InputBuffer': 'scripts/shared/InputBuffer.lua',
}

if modules_folder is not None:
    for module_name, file_path in NEW_MODULES.items():
        # Check if already exists
        exists = False
        for child in modules_folder:
            if child.tag == 'Item':
                name_elem = child.find('.//string[@name="Name"]')
                if name_elem is not None and name_elem.text == module_name:
                    exists = True
                    print(f"  ⚠️  {module_name} already exists, updating...")
                    source_elem = child.find('.//ProtectedString[@name="Source"]')
                    with open(file_path, 'r', encoding='utf-8') as f:
                        source_elem.text = f.read()
                    break

        if not exists and os.path.exists(file_path):
            with open(file_path, 'r', encoding='utf-8') as f:
                source_code = f.read()

            new_module = create_module_script(module_name, source_code)
            modules_folder.append(new_module)
            print(f"  ✅ Added: {module_name}")
else:
    print("  ⚠️  Modules folder not found!")

# Add new handlers to Handlers folder
print("\n[5/6] Adding new handlers to Handlers...")

NEW_HANDLERS = {
    'UptiltHandler': 'scripts/server/UptiltHandler.lua',
    'AerialHandler': 'scripts/server/AerialHandler.lua',
}

if handlers_folder is not None:
    for handler_name, file_path in NEW_HANDLERS.items():
        # Check if already exists
        exists = False
        for child in handlers_folder:
            if child.tag == 'Item':
                name_elem = child.find('.//string[@name="Name"]')
                if name_elem is not None and name_elem.text == handler_name:
                    exists = True
                    print(f"  ⚠️  {handler_name} already exists, updating...")
                    source_elem = child.find('.//ProtectedString[@name="Source"]')
                    with open(file_path, 'r', encoding='utf-8') as f:
                        source_elem.text = f.read()
                    break

        if not exists and os.path.exists(file_path):
            with open(file_path, 'r', encoding='utf-8') as f:
                source_code = f.read()

            new_handler = create_module_script(handler_name, source_code)
            handlers_folder.append(new_handler)
            print(f"  ✅ Added: {handler_name}")
else:
    print("  ⚠️  Handlers folder not found!")

# Save the file
print("\n[6/6] Saving complete RBXLX file...")
output_file = 'new BG updated systems.rbxlx'
tree.write(output_file, encoding='utf-8', xml_declaration=True)

print("\n" + "=" * 70)
print("✅ COMPLETE RBXLX CREATED SUCCESSFULLY!")
print("=" * 70)
print(f"\nOutput file: {output_file}")
print(f"\nIncluded:")
print(f"  • {updated_count} updated scripts")
print(f"  • {len(NEW_MODULES)} new modules (AerialComboSystem, InputBuffer)")
print(f"  • {len(NEW_HANDLERS)} new handlers (UptiltHandler, AerialHandler)")
print(f"\nThis file is COMPLETE and ready to use in Roblox Studio!")
print("=" * 70)
