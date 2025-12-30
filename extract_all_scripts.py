#!/usr/bin/env python3
import xml.etree.ElementTree as ET
import os

# Parse the rbxlx file
tree = ET.parse('bggame.rbxlx')
root = tree.getroot()

# Create output directories
os.makedirs('scripts/client', exist_ok=True)
os.makedirs('scripts/server', exist_ok=True)
os.makedirs('scripts/shared', exist_ok=True)
os.makedirs('scripts/characters', exist_ok=True)
os.makedirs('scripts/attacks', exist_ok=True)

scripts_extracted = []

# Find all Script, LocalScript, and ModuleScript items
for item in root.iter('Item'):
    item_class = item.get('class')
    if item_class in ['Script', 'LocalScript', 'ModuleScript']:
        # Get the script name
        name_elem = item.find('.//string[@name="Name"]')
        name = name_elem.text if name_elem is not None and name_elem.text else "Unnamed"

        # Get the source code
        source_elem = item.find('.//ProtectedString[@name="Source"]')
        source = source_elem.text if source_elem is not None and source_elem.text else ""

        # Determine output directory based on script type and name
        if item_class == 'LocalScript':
            output_dir = 'scripts/client'
        elif item_class == 'Script':
            output_dir = 'scripts/server'
        elif 'Handler' in name or 'Manager' in name or 'Registry' in name:
            output_dir = 'scripts/shared'
        elif name in ['Arthur', 'ArthurVFX']:
            output_dir = 'scripts/characters'
        elif name in ['M1', 'Uptilt', 'Aerial']:
            output_dir = 'scripts/attacks'
        else:
            output_dir = 'scripts/shared'

        # Create unique filename
        filename = f"{name}.lua"
        filepath = os.path.join(output_dir, filename)

        # Handle duplicate names
        counter = 1
        while os.path.exists(filepath):
            filename = f"{name}_{counter}.lua"
            filepath = os.path.join(output_dir, filename)
            counter += 1

        # Write the script to file
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(source)

        scripts_extracted.append({
            'type': item_class,
            'name': name,
            'path': filepath,
            'lines': len(source.split('\n')) if source else 0
        })

# Print summary
print(f"Extracted {len(scripts_extracted)} scripts:\n")
for script in scripts_extracted:
    print(f"[{script['type']:12}] {script['name']:25} -> {script['path']} ({script['lines']} lines)")

print(f"\n✅ All scripts extracted successfully!")
