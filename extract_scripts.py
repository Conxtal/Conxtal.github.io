#!/usr/bin/env python3
import re
import xml.etree.ElementTree as ET

# Parse the rbxlx file
tree = ET.parse('bggame.rbxlx')
root = tree.getroot()

scripts = []

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

        scripts.append({
            'type': item_class,
            'name': name,
            'source': source,
            'lines': len(source.split('\n')) if source else 0
        })

# Print summary
print(f"Found {len(scripts)} scripts:\n")
for i, script in enumerate(scripts, 1):
    print(f"{i}. [{script['type']}] {script['name']} ({script['lines']} lines)")

print("\n" + "="*60)
