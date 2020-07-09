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

variables = []
values_per_variable = {}
def bayesian2logical(node, value):
    if (node, value) in variables:
        return str(variables.index((node, value)) + 1)
    index = next(i for i, (n, v) in enumerate(variables) if n == node)
    return '-{}'.format(index + 1)

def construct_cpt(name, parents, probabilities):
    parent_patterns = itertools.product(*[values_per_variable[p] for p in parents])
    clauses = []
    i = 0
    for pattern in parent_patterns:
        probability_denominator = 1
        probability = 0
        conditions = [bayesian2logical(parent, parent_value) for parent, parent_value in zip(parents, pattern)]
        for j in range(len(values_per_variable[name])):
            current_value = bayesian2logical(name, values_per_variable[name][j])
            if current_value.startswith('-'):
                i += 1
                continue
            if probabilities[i] == '0':
                clauses.append('w {} {}'.format(' '.join([current_value] + conditions), probabilities[i]))
                continue
            previous_values = [bayesian2logical(name, value)
                               for k, value in enumerate(values_per_variable[name][:j])
                               if probabilities[i-len(values_per_variable[name][:j])+k] != '0'] if len(
                                       values_per_variable[name]) > 2 else []
            clauses += ['w {} {} 0'.format(current_value, previous_value) for previous_value in previous_values]
            negated_previous = [(v[1:] if v.startswith('-') else '-' + v) for v in previous_values]
            probability = float(probabilities[i]) / probability_denominator
            probability_denominator *= 1 - probability
            clauses.append('w {} {}'.format(' '.join([current_value] + negated_previous + conditions), probability))
            i += 1
    return clauses

def encode_text(text, mode):
    assert(mode == 'dne' or mode == 'net')
    clauses = []
    for node in re.finditer(NODE_RE, text):
        end_of_name = node.end()
        name = node.group(1).lstrip().rstrip()
        values = re.split(STATE_SPLITTER_RE[mode], re.search(STATES_RE[mode], text[end_of_name:]).group(1))
        values_per_variable[name] = values
        if len(values) == 2:
            variables.append((name, 'true') if 'true' in values else (name, values[0]))
        else:
            variables.extend([(name, v) for v in values])
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
    return [bayesian2logical(inst.attrib['id'], inst.attrib['value']) + ' 0'
            for inst in ET.parse(filename).findall('inst')]

def get_format(filename):
    # Hugin and NET are equivalent formats
    assert(filename.endswith('.dne') or filename.endswith('.net') or filename.endswith('.hugin'))
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
        variable = variables[-1][0]
        literal = (variables.index((variable, 'true')) if (variable, 'true') in variables else
                   next(i for i, t in enumerate(variables) if t[0] == variable)) + 1
        clauses.append('{} 0'.format(literal))
        num_clauses = 1

    encoding = 'p cnf {} {}\n'.format(len(variables), num_clauses) + '\n'.join(clauses) + '\n'
    with open(network + '.cnf', 'w') as f:
        f.write(encoding)

def encode_using_ace(network, evidence, encoding):
    mode = get_format(network)
    command = ACE + ['-' + encoding, network]
    if evidence:
        command += ['-e', evidence]
    subprocess.run(command)

    # Which marginal probability should we compute?
    with open(network) as f:
        text = f.read()
    goal_node, goal_node_end = [(i.group(1), i.end()) for i in re.finditer(NODE_RE, text)][-1]
    values = re.split(STATE_SPLITTER_RE[mode], re.search(STATES_RE[mode], text[goal_node_end:]).group(1))
    goal_value = values.index('true') if 'true' in values else 0

    # Move weights from the LMAP file to the CNF file
    with open(network + '.lmap') as f:
        lines = f.readlines()
    weights = {}
    max_literal = 0
    for line in lines:
        if line.startswith('cc$I') or line.startswith('cc$C'):
            components = line.split('$')
            literal = int(components[2])
            weight = components[3]
            weights[literal] = weight
            max_literal = max(max_literal, abs(literal))
            if components[5] == goal_node and components[6] == '{}\n'.format(goal_value):
                goal_literal = literal
    weights_line = []
    for literal in range(1, max_literal + 1):
        weights_line += [weights[literal], weights[-literal]]
    encoding = 'c weights ' + ' '.join(weights_line) + '\n'
    if evidence is None:
        encoding += '{} 0\n'.format(goal_literal)
    with open(network + '.cnf', 'a') as f:
        f.write(encoding)

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
