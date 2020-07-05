import argparse
import itertools
import os
import re
import subprocess
import xml.etree.ElementTree as ET

ACE = ['./ace/compile', '-encodeOnly', '-noEclause']
NODE_RE = r'\nnode (\w+)'
NET_STATES_RE = r'states = \(\s*"([^()]*)"\s*\)'
DNE_STATES_RE = r'states = \(([^()]*)\)'
PARENTS_RE = r'parents = \(([^()]*)\)'
PROBS_RE = r'probs = ([^;]*);'
POTENTIAL_RE = r'\npotential([^{]*){([^}]*)}'
NUMBER_RE = r'\d+\.?\d*'
PROB_SPLITTER_RE = r'[, ()\n\t]+'

names = []
values_per_variable = {}
def name2int(name):
    return str(names.index(name)+1)

def probability_conditions(negation_pattern, parents):
    for negate, parent in zip(negation_pattern, parents):
        yield ('-' if negate else '') + name2int(parent)

def construct_binary_cpt(name, parents, probabilities, reverse=False):
    assert(len(probabilities) == 2**len(parents))
    possible_negations = itertools.product([True, False] if reverse else [False, True], repeat=len(parents))
    return ['w ' + ' '.join([name2int(name)] + list(probability_conditions(negation_pattern, parents)) + [prob])
            for negation_pattern, prob in zip(possible_negations, probabilities)]

def construct_general_cpt(name, parents, probabilities):
    parent_patterns = itertools.product(*[values_per_variable[p] for p in parents])
    clauses = []
    i = 0
    for pattern in parent_patterns:
        probability_denominator = 1
        probability = 0
        conditions = [name2int((parent, parent_value)) for parent, parent_value in zip(parents, pattern)]
        for j in range(len(values_per_variable[name])):
            current_value = name2int((name, values_per_variable[name][j]))
            previous_values = [name2int((name, value)) for value in values_per_variable[name][:j]]
            clauses += ['w {} {} 0'.format(current_value, previous_value) for previous_value in previous_values]
            negated_previous = ['-{}'.format(v) for v in previous_values]
            probability = float(probabilities[i]) / probability_denominator
            probability_denominator *= 1 - probability
            clauses.append('w {} {}'.format(' '.join([current_value] + negated_previous + conditions), probability))
            i += 1
    return clauses

def encode_dne(text):
    clauses = []
    for node in re.finditer(NODE_RE, text):
        end_of_name = node.end()
        name = node.group(1).lstrip().rstrip()
        names.append(name)

        values = re.search(DNE_STATES_RE, text[end_of_name:]).group(1)
        assert(values == 'true, false')

        parents = [s.lstrip().rstrip()
                   for s in re.search(PARENTS_RE, text[end_of_name:]).group(1).split(', ') if s != '']
        # Parse only the numbers and discard every other one
        probs_str = re.search(PROBS_RE, text[end_of_name:]).group(1)
        probs = [p for p in re.split(PROB_SPLITTER_RE, probs_str) if p != ''][::2]
        clauses += construct_cpt(name, parents, probs)
    return clauses

def encode_net(text):
    clauses = []
    for node in re.finditer(NODE_RE, text):
        end_of_name = node.end()
        name = node.group(1).lstrip().rstrip()
        values = re.search(NET_STATES_RE, text[end_of_name:]).group(1).split('" "')
        if len(values) == 2:
            assert(values == ['false', 'true'])
            names.append(name)
        else:
            names.extend([(name, v) for v in values])
            values_per_variable[name] = values

    for potential in re.finditer(POTENTIAL_RE, text):
        header = re.findall(r'\w+', potential.group(1))
        probabilities = re.findall(NUMBER_RE, potential.group(2))
        if len(values) == 2:
            # First false, then true
            clauses += construct_binary_cpt(header[0], header[1:], probabilities[1::2], reverse=True)
        else:
            clauses += construct_general_cpt(header[0], header[1:], probabilities)
    return clauses

def encode_inst_evidence(filename):
    if filename is None:
        return []
    clauses = []
    for inst in ET.parse(filename).findall('inst'):
        assert(inst.attrib['value'] in ['true', 'false'])
        sign = '' if inst.attrib['value'] == 'true' else '-'
        clauses.append(sign + name2int(inst.attrib['id']) + ' 0')
    return clauses

def encode(network, evidence):
    assert(network.endswith('.dne') or network.endswith('.net') or network.endswith('.hugin'))
    with open(network) as f:
        text = f.read()
        # Hugin and NET are equivalent formats
        clauses = encode_dne(text) if network.endswith('.dne') else encode_net(text)

    evidence_clauses = encode_inst_evidence(evidence)
    if evidence_clauses:
        num_clauses = len(evidence_clauses)
        clauses += evidence_clauses
    else:
        # Add a goal clause if necessary: the last value of the last variable
        clauses.append(clauses[-1].split(' ')[1] + ' 0')
        num_clauses = 1

    encoding = 'p cnf {} {}\n'.format(len(names), num_clauses) + '\n'.join(clauses) + '\n'
    with open(network + '.cnf', 'w') as f:
        f.write(encoding)

def encode_using_ace(network, evidence, encoding):
    command = ACE + ['-' + encoding, network]
    if evidence:
        command += ['-e', evidence]
    subprocess.run(command)

    # Which marginal probability should we compute?
    with open(network) as f:
        text = f.read()
    goal_node, goal_node_end = [(i.group(1), i.end()) for i in re.finditer(NODE_RE, text)][-1]
    goal_num_values = len(re.search(NET_STATES_RE, text[goal_node_end:]).group(1).split('" "'))
    # TODO: default value = 2

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
            if components[5] == goal_node and components[6] == '{}\n'.format(goal_num_values - 1):
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
