import argparse
import itertools
import os
import re
import subprocess
import xml.etree.ElementTree as ET
from fractions import Fraction

EPSILON = 0.000001
# Software dependencies
ACE = ['deps/ace/compile', '-encodeOnly', '-noEclause']
ACE_LEGACY_BASIC = ['deps/ace/compile', '-forceC2d']
ACE_LEGACY = {'d02': ACE_LEGACY_BASIC + ['-d02', '-dtHypergraph', '3'],
              'cd05': ACE_LEGACY_BASIC + ['-cd05', '-dtBnOrder'],
              'cd06': ACE_LEGACY_BASIC + ['-cd06', '-dtBnOrder']}
BN2CNF = ['deps/bn2cnf_linux', '-e', 'LOG', '-s', 'prime']
C2D = ['deps/ace/c2d_linux']

# Regular expressions
NODE_RE = r'\nnode (\w+)'
PARENTS_RE = r'parents = \(([^()]*)\)'
PROBS_RE = r'probs = ([^;]*);'
POTENTIAL_RE = r'\npotential([^{]*){([^}]*)}'
NUMBER_RE = r'\d+\.?\d*'
PROB_SPLITTER_RE = r'[, ()\n\t]+'
STATES_RE = {'dne': r'states = \(([^()]*)\)', 'net': r'states = \(\s*"([^()]*)"\s*\)'}
STATE_SPLITTER_RE = {'net': r'"\s*"', 'dne': r',\s*'}
VARIABLE_MAP_RE = r'(\d+) = (.+)'

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
        return str(self._var2lit[(variable, value)])

    def get_min_literal(self, variable):
        return str(min(lit for lit, (var, val) in self._lit2var.items()
                       if var == variable))

    def get_true_or_min_literal(self, variable):
        return (self.get_literal(variable, 'true') if (variable, 'true') in self
                else self.get_min_literal(variable))

    def get_literal_string(self, variable, value):
        return (self.get_literal(variable, value)
                if (variable, value) in self
                else '-{}'.format(self.get_min_literal(variable)))

    def get_last_variable(self):
        return self._lit2var[self._next_lit - 1][0]

    def __len__(self):
        return self._next_lit - 1

variables = LiteralDict()
values_per_variable = {}

def construct_weights(literal, num_values, parents, probabilities,
                      probability_index, negate_probability):
    rows_of_cpt = itertools.product(*[values_per_variable[p] for p in parents])
    clauses = []
    for row_index, row in enumerate(rows_of_cpt):
        conditions = [variables.get_literal_string(parent, parent_value)
                      for parent, parent_value in zip(parents, row)]
        p = Fraction(probabilities[probability_index]).limit_denominator()
        clauses.append('w {} {} {}'.format(' '.join([literal] + conditions),
                                           float(p), float(negate_probability(p))))
        probability_index += num_values
    return clauses

def find_goal_value(variable):
    if 'true' in values_per_variable[variable]:
        return (values_per_variable[variable].index('true'),
                variables.get_literal(variable, 'true'))
    return 0, variables.get_min_literal(variable)

def cpt2cnf(parents, probabilities):
    'Transform a Bayesian network represented as two dictionaries to a list of clauses'
    clauses = []
    for variable in parents:
        if len(values_per_variable[variable]) == 2:
            index, literal = find_goal_value(variable)
            num_values = len(values_per_variable[variable])
            clauses += construct_weights(literal, num_values, parents[variable],
                                         probabilities[variable], index,
                                         lambda p: 1 - p)
        else:
            values = [variables.get_literal_string(variable, v)
                      for v in values_per_variable[variable]]
            clauses += ['{} 0'.format(' '.join(values))] + [
                '-{} -{} 0'.format(values[i], values[j])
                for i in range(len(values))
                for j in range(i + 1, len(values))]
            for i, value in enumerate(values):
                clauses += construct_weights(value,
                                             len(values_per_variable[variable]),
                                             parents[variable],
                                             probabilities[variable], i,
                                             lambda p: 1)
    return clauses

def cpt2uai(parents_dict, probabilities_dict):
    variables = list(parents_dict.keys()) # Fix an order on variables
    parents = [[variables.index(v)
                for v in parents_dict[variables[variable]]]
               for variable in range(len(variables))]
    probabilities = [probabilities_dict[variables[v]]
                     for v in range(len(variables))]

    # The first four lines
    lines = ['BAYES', str(len(variables)),
             ' '.join(str(len(values_per_variable[variables[v]]))
                      for v in range(len(variables))),
             str(len(variables))]

    # The structure of the network
    for variable in range(len(variables)):
        line = ([len(parents[variable]) + 1] + sorted(parents[variable]) +
                [variable])
        lines.append(' '.join([str(i) for i in line]))

    # Conditional probability tables
    for variable in range(len(variables)):
        lines += [str(len(probabilities[variable]))]
        # Assign each row of probabilities to a set of (parent_var, parent_val)
        # pairs, then retrieve them in a different order
        keys = itertools.product(
            *[[(p, v) for v in values_per_variable[variables[p]]]
              for p in parents[variable]])
        rearranged_probabilities = {}
        num_values = len(values_per_variable[variables[variable]])
        for i, key in enumerate(keys):
            first_index = i * num_values
            last_index = (i + 1) * num_values
            rearranged_probabilities[frozenset(key)] = probabilities[variable][
                first_index:last_index]
        new_keys = itertools.product(
            *[[(p, v) for v in values_per_variable[variables[p]]]
              for p in sorted(parents[variable])])
        lines += [' '.join(rearranged_probabilities[frozenset(key)])
                  for key in new_keys]
    return lines, variables

def parse_network(filename, output_uai=False):
    'The main function responsible for parsing Bayesian networks'
    mode = get_format(filename)
    assert mode == 'dne' or mode == 'net'

    with open(filename, encoding='ISO-8859-1') as f:
        text = f.read()

    parents_dict = {}
    probabilities_dict = {}
    for node in re.finditer(NODE_RE, text):
        end_of_name = node.end()
        name = node.group(1).lstrip().rstrip()
        values = re.split(STATE_SPLITTER_RE[mode],
                          re.search(STATES_RE[mode],
                                    text[end_of_name:]).group(1))
        values_per_variable[name] = values
        if len(values) == 2:
            variables.add(name, 'true' if 'true' in values else values[0])
        else:
            for v in values:
                variables.add(name, v)
        if mode == 'dne':
            parents_re = re.search(PARENTS_RE, text[end_of_name:]).group(1)
            parents = [s.lstrip().rstrip() for s in parents_re.split(', ') if s != '']
            probs_str = re.search(PROBS_RE, text[end_of_name:]).group(1)
            probs = [p for p in re.split(PROB_SPLITTER_RE, probs_str) if p != '']
            parents_dict[name] = parents
            probabilities_dict[name] = probs

    if mode == 'net':
        for potential in re.finditer(POTENTIAL_RE, text):
            header = re.findall(r'\w+', potential.group(1))
            probabilities = re.findall(NUMBER_RE, potential.group(2))
            parents_dict[header[0]] = header[1:]
            probabilities_dict[header[0]] = probabilities
    return (cpt2uai(parents_dict, probabilities_dict) if output_uai else
            cpt2cnf(parents_dict, probabilities_dict))

def encode_inst_evidence(filename, indicators=None, variables_map=None):
    if filename is None:
        return []
    instantiations = ET.parse(filename).findall('inst')
    if indicators is None:
        return [variables.get_literal_string(inst.attrib['id'],
                                             inst.attrib['value']) + ' 0'
                for inst in instantiations]
    evidence = []
    for inst in instantiations:
        variable = variables_map.index(inst.attrib['id'])
        values = values_per_variable[inst.attrib['id']]
        value = values.index(inst.attrib['value'])
        evidence += indicators[(variable, value)]
    return evidence

def evidence_file_is_empty(evidence_file):
    return evidence_file is None or ET.parse(evidence_file).find('inst') is None

def get_format(filename):
    # Hugin and NET are equivalent formats
    assert filename.endswith('.dne') or filename.endswith('.net') or filename.endswith('.hugin')
    return 'net' if filename.endswith('.net') else 'dne'

def encode(network, evidence):
    clauses = parse_network(network)

    evidence_clauses = encode_inst_evidence(evidence)
    if evidence_clauses:
        clauses += evidence_clauses
    else: # Add a goal clause if necessary (the first value of the last node (or 'true', if available))
        literal = variables.get_true_or_min_literal(variables.get_last_variable())
        clauses.append('{} 0'.format(literal))

    num_clauses = sum([not c.startswith('w') for c in clauses])
    encoding = 'p cnf {} {}\n'.format(len(variables), num_clauses) + '\n'.join(clauses) + '\n'
    with open(network + '.cnf', 'w') as f:
        f.write(encoding)

def identify_goal(text, mode):
    'Which marginal probability should we compute?'
    goal_node, goal_node_end = [(i.group(1), i.end()) for i in re.finditer(NODE_RE, text)][-1]
    values = re.split(STATE_SPLITTER_RE[mode], re.search(STATES_RE[mode], text[goal_node_end:]).group(1))
    goal_value = 'true' if 'true' in values else values[0]
    goal_value_index = values.index(goal_value)
    return goal_node, goal_value_index, goal_value

def new_evidence_file(network_filename, variable, value):
    'Create a new evidence file for a goal variable and value'
    new_filename = network_filename + '.inst'
    with open(new_filename, 'w') as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<instantiation><inst id="{}" value="{}"/></instantiation>'.format(variable, value))
    return new_filename

def encode_using_ace(network, evidence_file, encoding, legacy_mode):
    # Identify the goal
    with open(network, encoding='ISO-8859-1') as f:
        text = f.read()
    mode = get_format(network)
    goal_node, goal_value_index, goal_value = identify_goal(text, mode)

    if legacy_mode and encoding != 'sbk05':
        subprocess.run(ACE_LEGACY[encoding] +
                       [network, '-e',
                        new_evidence_file(network, goal_node, goal_value)
                        if evidence_file_is_empty(evidence_file)
                        else evidence_file])
        return

    subprocess.run(ACE + ['-' + encoding, network])

    # Make a variable -> list of values map
    values = {node.group(1) : re.split(STATE_SPLITTER_RE[mode],
                                       re.search(STATES_RE[mode],
                                                 text[node.end():]).group(1))
              for node in re.finditer(NODE_RE, text)}

    # Move weights from the LMAP file to the CNF file
    # (and convert the goal to a literal)
    weights = {}
    max_literal = 0
    for line in open(network + '.lmap'):
        if line.startswith('cc$I') or line.startswith('cc$C') or line.startswith('cc$P'):
            components = line.split('$')
            literal = int(components[2])
            weight = components[3]
            weights[literal] = weight
            max_literal = max(max_literal, abs(literal))
            if line.startswith('cc$I'):
                variable = components[5]
                value = int(components[6].rstrip())
                if literal > 0:
                    variables.add_literal(variable, values[variable][value], literal)
                if variable == goal_node and value == goal_value_index:
                    goal_literal = literal

    evidence = ('{} 0\n'.format(goal_literal)
                if evidence_file_is_empty(evidence_file)
                else '\n'.join(encode_inst_evidence(evidence_file)))

    if legacy_mode:
        weight_encoding = '\n'.join('w {} {}'.format(
            literal, -1 if abs(float(weights[literal]) - 1) < EPSILON
            else weights[literal]) for literal in range(1, max_literal + 1))
    else:
        weight_encoding = 'c weights ' + ' '.join(
            l for literal in range(1, max_literal + 1)
            for l in [weights[literal], weights[-literal]])

    with open(network + '.cnf', 'a') as f:
        f.write(evidence + '\n' + weight_encoding + '\n')

def encode_using_bn2cnf(network_filename, evidence_file, legacy_mode):
    # Translate the Bayesian network to the UAI format and run the encoder
    encoded_clauses, variables = parse_network(network_filename, True)
    uai_filename = network_filename + '.uai'
    cnf_filename = network_filename + '.cnf'
    weights_filename = uai_filename + '.weights'
    variables_filename = uai_filename + '.variables'
    with open(uai_filename, 'w') as f:
        f.write('\n'.join(encoded_clauses) + '\n')
    subprocess.run(BN2CNF + ['-i', uai_filename, '-o', cnf_filename,
                             '-w', weights_filename, '-v', variables_filename])

    # Translate weights to the right format
    if legacy_mode:
        encoded_weights = []
    else:
        positive_weights = {}
        negative_weights = {}
        with open(weights_filename) as f:
            for line in f:
                words = line.split()
                assert(len(words) == 2)
                literal = int(words[0])
                if literal < 0:
                    negative_weights[-literal] = words[1]
                else:
                    positive_weights[literal] = words[1]

        encoded_weights = ['w {} {} {}'.format(literal,
                                               positive_weights[literal],
                                               negative_weights[literal])
                           if literal in negative_weights
                           else 'w {} {}'.format(literal,
                                                 positive_weights[literal])
                           for literal in positive_weights]

    # Map (variable, value) pairs to CNF formulas
    # (as lists of lines in DIMACS syntax)
    indicators = {}
    with open(variables_filename) as f:
        text = f.read()
    for line in re.finditer(VARIABLE_MAP_RE, text):
        #.group(1)[2:-2]
        variable = line.group(1)
        values = [v.split(', ') for v in line.group(2)[2:-2].split('][')]
        for value in range(len(values)):
            indicators[(int(variable), value)] = [l + ' 0' for l in values[value]]

    # Incorporate evidence (or select a goal)
    if not evidence_file_is_empty(evidence_file):
        encoded_evidence = encode_inst_evidence(evidence_file, indicators,
                                                variables)
    else:
        # Identify the goal formula
        with open(network_filename) as f:
            text = f.read()
        goal_variable_string, goal_value, _ = identify_goal(text, get_format(network_filename))
        goal_variable = variables.index(goal_variable_string)
        encoded_evidence = indicators[(goal_variable, goal_value)]

    # Update the number of clauses
    with open(cnf_filename) as f:
        lines = f.read().splitlines()
    words = lines[0].split()
    assert(len(words) == 4)
    words[3] = str(int(words[3]) + len(encoded_evidence))
    lines[0] = ' '.join(words)

    # Put everything together and write to a file
    with open(cnf_filename, 'w') as f:
        f.write('\n'.join(lines + encoded_weights + encoded_evidence) + '\n')

    if legacy_mode:
        subprocess.run(C2D + ['-in', cnf_filename])

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Encode Bayesian networks into instances of weighted model counting (WMC)')
    parser.add_argument('network', metavar='network', help='a Bayesian network (in one of DNE/NET/Hugin formats)')
    parser.add_argument('encoding', choices=['bklm16', 'cd05', 'cd06', 'cw', 'd02', 'sbk05'], help='choose a WMC encoding')
    parser.add_argument('-e', dest='evidence', help='evidence file (in the INST format)')
    parser.add_argument('-l', action='store_true', help='legacy mode, i.e., the encoding is compatible with the original compiler or model counter (and not ADDMC)')
    args = parser.parse_args()
    if args.encoding == 'cw':
        encode(args.network, args.evidence)
    elif args.encoding == 'bklm16':
        encode_using_bn2cnf(args.network, args.evidence, args.l)
    else:
        encode_using_ace(args.network, args.evidence, args.encoding, args.l)
