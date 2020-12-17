# A collection of functions and classes used in multiple Python scripts

import re
import xml.etree.ElementTree as ET

NODE_RE = r'\nnode (\w+)'
STATE_SPLITTER_RE = {'net': r'"\s*"', 'dne': r',\s*'}
STATES_RE = {
    'dne': r'states = \(([^()]*)\)',
    'net': r'states = \(\s*"([^()]*)"\s*\)'
}


class BayesianNetwork:
    parents = {}
    values = {}
    probabilities = {}
    _last_variable = None

    def goal_value(self, variable):
        return ((self.values[variable].index('true'),
                 'true') if 'true' in self.values[variable] else
                (0, self.values[variable][0]))

    def goal(self):
        _, value = self.goal_value(self._last_variable)
        return (self._last_variable, value)

    def __init__(self, filename):
        file_format = get_file_format(filename)
        with open(filename, encoding='ISO-8859-1') as f:
            text = f.read()

        for node in re.finditer(NODE_RE, text):
            end_of_name = node.end()
            name = node.group(1).lstrip().rstrip()
            self._last_variable = name
            self.values[name] = re.split(
                STATE_SPLITTER_RE[file_format],
                re.search(STATES_RE[file_format], text[end_of_name:]).group(1))
            if file_format == 'dne':
                parents_str = re.search(r'parents = \(([^()]*)\)',
                                        text[end_of_name:]).group(1)
                self.parents[name] = [
                    s.lstrip().rstrip() for s in parents_str.split(', ')
                    if s != ''
                ]
                probs_str = re.search(r'probs = ([^;]*);',
                                      text[end_of_name:]).group(1)
                self.probabilities[name] = [
                    p for p in re.split(r'[, ()\n\t]+', probs_str) if p != ''
                ]

        if file_format == 'net':
            for potential in re.finditer(r'\npotential([^{]*){([^}]*)}', text):
                header = re.findall(r'\w+', potential.group(1))
                probs = re.findall(r'\d+\.?\d*', potential.group(2))
                self.parents[header[0]] = header[1:]
                self.probabilities[header[0]] = probs


def get_file_format(filename):
    # Hugin and NET are equivalent formats
    assert (filename.endswith('.dne') or filename.endswith('.net')
            or filename.endswith('.hugin'))
    return 'net' if filename.endswith('.net') else 'dne'


def parse_evidence(filename):
    for inst in ET.parse(filename).findall('inst'):
        yield (inst.attrib['id'], inst.attrib['value'])


def empty_evidence(filename):
    return filename is None or ET.parse(filename).find('inst') is None
