import zipfile
import xml.etree.ElementTree as ET
import re

z = zipfile.ZipFile('D:/DATA COLLECTION TOOL/SignBridge_Data_Collection_Tool_Master_Implementation_Plan.docx')
xml_content = z.read('word/document.xml')
z.close()

root = ET.fromstring(xml_content)

# Extract text with paragraph structure
paragraphs = []
for elem in root.iter():
    if elem.tag.endswith('}p'):  # paragraph
        text = ''.join(node.text for node in elem.iter() if node.text and node.tag.endswith('}t'))
        if text.strip():
            paragraphs.append(text.strip())

full_text = '\n'.join(paragraphs)

with open('D:/DATA COLLECTION TOOL/extracted_text.txt', 'w', encoding='utf-8') as f:
    f.write(full_text)

print(f'Extracted {len(paragraphs)} paragraphs')
