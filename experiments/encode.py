import argparse
import itertools
import os
import re
import subprocess
import xml.etree.ElementTree as ET

ACE = ['./ace/compile', '-encodeOnly', '-noEclause']
NODE_RE = r'\nnode (\w+)'
PARENTS_RE = r'parents = \(([^()]*)\)'
PROBS_RE = r'probs = ([^;]*);'
POTENTIAL_RE = r'\npotential([^{]*){([^}]*)}'
NUMBER_RE = r'\d+\.?\d*'
PROB_SPLITTER_RE = r'[, ()\n\t]+'
STATES_RE = {'dne': r'states = \(([^()]*)\)', 'net': r'states = \(\s*"([^()]*)"\s*\)'}
STATE_SPLITTER_RE = {'net': r'"\s*"', 'dne': r',\s*'}

class LiteralDict:
    _lit2var = {}
    _var2lit = {}
    _next_lit = 1

    def add_literal(self, variable, value, literal):
        assert literal >= self._next_lit
        self._lit2var[literal] = (variable, value)
        self._var2lit[(variable, value)] = literal
        self._next_lit = literal + 1

    def add(self, variable, value):
        self.add_literal(variable, value, self._next_lit)

    def __contains__(self, variableAndValue):
        return variableAndValue in self._var2lit

    def get_literal(self, variable, value):
        return self._var2lit[(variable, value)]

    def get_min_literal(self, variable):
        return min(lit for lit, (var, val) in self._lit2var.items() if var == variable)

    def get_true_or_min_literal(self, variable):
        return self.get_literal(variable, 'true') if (variable, 'true') in self else self.get_min_literal(variable)

    def get_literal_string(self, variable, value):
        return (str(self.get_literal(variable, value)) if (variable, value) in self else
                '-{}'.format(self.get_min_literal(variable)))

    def get_last_variable(self):
        return self._lit2var[self._next_lit - 1][0]

    def __len__(self):
        return self._next_lit - 1

variables = LiteralDict()
values_per_variable = {}

def construct_cpt(name, parents, probabilities):
    parent_patterns = itertools.product(*[values_per_variable[p] for p in parents])
    clauses = []
    i = 0
    for pattern in parent_patterns:
        probability_denominator = 1
        probability = 0
        conditions = [variables.get_literal_string(parent, parent_value)
                      for parent, parent_value in zip(parents, pattern)]
        for j in range(len(values_per_variable[name])):
            current_value = variables.get_literal_string(name, values_per_variable[name][j])
            if current_value.startswith('-'):
                i += 1
                continue
            if float(probabilities[i]) == 0:
                clauses.append('w {} {}'.format(' '.join([current_value] + conditions), probabilities[i]))
                continue
            previous_values = [variables.get_literal_string(name, value)
                               for k, value in enumerate(values_per_variable[name][:j])
                               if float(probabilities[i-len(values_per_variable[name][:j])+k]) != 0] if len(
                                       values_per_variable[name]) > 2 else []
            clauses += ['w {} {} 0'.format(current_value, previous_value) for previous_value in previous_values]
            negated_previous = [(v[1:] if v.startswith('-') else '-' + v) for v in previous_values]
            probability = float(probabilities[i]) / probability_denominator
            probability_denominator *= 1 - probability
            clauses.append('w {} {}'.format(' '.join([current_value] + negated_previous + conditions), probability))
            i += 1
    return clauses

def encode_text(text, mode):
    assert mode == 'dne' or mode == 'net'
    clauses = []
    for node in re.finditer(NODE_RE, text):
        end_of_name = node.end()
        name = node.group(1).lstrip().rstrip()
        values = re.split(STATE_SPLITTER_RE[mode], re.search(STATES_RE[mode], text[end_of_name:]).group(1))
        values_per_variable[name] = values
        if len(values) == 2:
            if 'true' in values:
                variables.add(name, 'true')
            else:
                variables.add(name, values[0])
        else:
            for v in values:
                variables.add(name, v)
        if mode == 'dne':
            parents = [s.lstrip().rstrip()
                       for s in re.search(PARENTS_RE, text[end_of_name:]).group(1).split(', ') if s != '']
            probs_str = re.search(PROBS_RE, text[end_of_name:]).group(1)
            probs = [p for p in re.split(PROB_SPLITTER_RE, probs_str) if p != '']
            clauses += construct_cpt(name, parents, probs)

    if mode == 'net':
        for potential in re.finditer(POTENTIAL_RE, text):
            header = re.findall(r'\w+', potential.group(1))
            probabilities = re.findall(NUMBER_RE, potential.group(2))
            clauses += construct_cpt(header[0], header[1:], probabilities)
    return clauses

def encode_inst_evidence(filename):
    if filename is None:
        return []
    return [variables.get_literal_string(inst.attrib['id'], inst.attrib['value']) + ' 0'
            for inst in ET.parse(filename).findall('inst')]

def evidence_file_is_empty(evidence_file):
    return evidence_file is None or ET.parse(evidence_file).find('inst') is None

def get_format(filename):
    # Hugin and NET are equivalent formats
    assert filename.endswith('.dne') or filename.endswith('.net') or filename.endswith('.hugin')
    return 'net' if filename.endswith('.net') else 'dne'

def encode(network, evidence):
    with open(network) as f:
        text = f.read()
        clauses = encode_text(text, get_format(network))

    evidence_clauses = encode_inst_evidence(evidence)
    if evidence_clauses:
        num_clauses = len(evidence_clauses)
        clauses += evidence_clauses
    else: # Add a goal clause if necessary (the first value of the last node (or 'true', if available))
        literal = variables.get_true_or_min_literal(variables.get_last_variable())
        clauses.append('{} 0'.format(literal))
        num_clauses = 1

    encoding = 'p cnf {} {}\n'.format(len(variables), num_clauses) + '\n'.join(clauses) + '\n'
    with open(network + '.cnf', 'w') as f:
        f.write(encoding)

def run_ace(network, evidence, encoding):
    command = ACE + ['-' + encoding, network]
    if evidence and encoding != 'sbk05':
        command += ['-e', evidence]
    subprocess.run(command)

# TODO: refactor!
def encode_using_ace(network, evidence_file, encoding):
    mode = get_format(network)
    run_ace(network, evidence_file, encoding)

    # Which marginal probability should we compute?
    with open(network) as f:
        text = f.read()
    goal_node, goal_node_end = [(i.group(1), i.end()) for i in re.finditer(NODE_RE, text)][-1]
    values = re.split(STATE_SPLITTER_RE[mode], re.search(STATES_RE[mode], text[goal_node_end:]).group(1))
    goal_value = values.index('true') if 'true' in values else 0
    # make a variable -> list of values map
    values = {}
    for node in re.finditer(NODE_RE, text):
        variable = node.group(1)
        v = re.split(STATE_SPLITTER_RE[mode], re.search(STATES_RE[mode], text[node.end():]).group(1))
        values[variable] = v

    # Move weights from the LMAP file to the CNF file
    with open(network + '.lmap') as f:
        lines = f.readlines()
    variablesAndValues = {} # to work around a bug with the sbk05 encoding
    weights = {}
    max_literal = 0
    for line in lines:
        if line.startswith('cc$I') or line.startswith('cc$C') or line.startswith('cc$P'):
            components = line.split('$')
            literal = int(components[2])
            weight = components[3]
            weights[literal] = weight
            max_literal = max(max_literal, abs(literal))
            if line.startswith('cc$I'):
                variable = components[5]
                value = int(components[6].rstrip())
                variablesAndValues[literal] = (variable, values[variable][value])
                if variable == goal_node and value == goal_value:
                    goal_literal = literal

    evidence = ''
    if encoding == 'sbk05':
        literals = sorted(l for l in variablesAndValues.keys() if l > 0)
        for i in literals:
            variables.add_literal(variablesAndValues[i][0], variablesAndValues[i][1], i)
        evidence = '\n'.join(encode_inst_evidence(evidence_file))
    if evidence_file_is_empty(evidence_file):
        evidence = '{} 0\n'.format(goal_literal)

    weight_encoding = 'c weights ' + ' '.join(l for literal in range(1, max_literal + 1)
                                              for l in [weights[literal], weights[-literal]])
    with open(network + '.cnf', 'a') as f:
        f.write(evidence + '\n' + weight_encoding + '\n')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Encode Bayesian networks into instances of weighted model counting (WMC)')
    parser.add_argument('network', metavar='network', help='a Bayesian network (in one of DNE/NET/Hugin formats)')
    parser.add_argument('encoding', choices=['d02', 'sbk05', 'cd05', 'cd06', 'db20'], help='a WMC encoding')
    parser.add_argument('-e', dest='evidence', help="evidence file (in the INST format)")
    args = parser.parse_args()
    if args.encoding == 'db20':
        encode(args.network, args.evidence)
    else:
        encode_using_ace(args.network, args.evidence, args.encoding)
