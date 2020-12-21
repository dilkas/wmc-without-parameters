import os
import xml.etree.ElementTree as ET

directory = 'data/original/Plan_Recognition/'
for filename in os.listdir(directory):
    if not filename.endswith('.xml'):
        continue
    input_xml = ET.parse(directory + filename)
    output_xml = ET.ElementTree(ET.Element('instantiation'))
    for inst in input_xml.findall('query/probability/evidence'):
        name = inst.find('id').text
        value = inst.find('state').text
        inst_tag = ET.SubElement(output_xml.getroot(),
                                 'inst',
                                 attrib={
                                     'id': name,
                                     'value': value
                                 })
    output_xml.write(directory + filename[:filename.rindex('.')] + '.inst')
