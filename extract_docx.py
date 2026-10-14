import zipfile
import xml.etree.ElementTree as ET

z = zipfile.ZipFile('D:/DATA COLLECTION TOOL/SignBridge_Data_Collection_Tool_Master_Implementation_Plan.docx')
xml_content = z.read('word/document.xml')
z.close()

root = ET.fromstring(xml_content)
text = ''.join(node.text for node in root.iter() if node.text)

with open('D:/DATA COLLECTION TOOL/extracted_text.txt', 'w', encoding='utf-8') as f:
    f.write(text)

print('Extracted successfully')
