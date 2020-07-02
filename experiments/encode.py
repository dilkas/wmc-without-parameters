import argparse
import itertools
import os
import re
import subprocess
import xml.etree.ElementTree as ET

ACE = ['./ace/compile', '-encodeOnly', '-noEclause']
names = []
def name2int(name):
    return str(names.index(name)+1)

def probability_conditions(negation_pattern, parents):
    for negate, parent in zip(negation_pattern, parents):
        yield ('-' if negate else '') + name2int(parent)

def construct_cpt(name, parents, probabilities, reverse=False):
    assert(len(probabilities) == 2**len(parents))
    possible_negations = itertools.product([True, False] if reverse else [False, True], repeat=len(parents))
    return ['w ' + ' '.join([name2int(name)] + list(probability_conditions(negation_pattern, parents)) + [prob])
            for negation_pattern, prob in zip(possible_negations, probabilities)]

def encode_dne(text):
    clauses = []
    for node in re.finditer(r'\nnode (\w+)', text):
        end_of_name = node.end()
        name = node.group(1).lstrip().rstrip()
        names.append(name)

        states = re.search(r'states = \(([^()]*)\)', text[end_of_name:]).group(1)
        assert(states == 'true, false')

        parents = [s.lstrip().rstrip()
                   for s in re.search(r'parents = \(([^()]*)\)', text[end_of_name:]).group(1).split(', ') if s != '']
        # Parse only the numbers and discard every other one
        probs_str = re.search(r'probs = ([^;]*);', text[end_of_name:]).group(1)
        probs = [p for p in re.split(r'[, ()\n\t]+', probs_str) if p != ''][0::2]
        clauses += construct_cpt(name, parents, probs)
    return clauses

def encode_net(text):
    clauses = []
    for node in re.finditer(r'\nnode (\w+)', text):
        end_of_name = node.end()
        name = node.group(1).lstrip().rstrip()
        names.append(name)
        states = re.search(r'states = \(([^()]*)\)', text[end_of_name:]).group(1).lstrip().rstrip()
        assert(states == '"false" "true"')
    for potential in re.finditer(r'\npotential([^{]*){([^}]*)}', text):
        header = re.findall(r'\w+', potential.group(1))
        probabilities = re.findall(r'\d+\.?\d*', potential.group(2))[1::2]
        assert(len(probabilities) == 2**(len(header) - 1))
        clauses += construct_cpt(header[0], header[1:], probabilities)
    return clauses

def encode_inst_evidence(filename):
    clauses = []
    for inst in ET.parse(filename).findall('inst'):
        assert(inst.attrib['value'] in ['true', 'false'])
        sign = '' if inst.attrib['value'] == 'true' else '-'
        clauses.append(sign + name2int(inst.attrib['id']) + ' 0')
    return clauses

def encode(network, evidence):
    assert(network.endswith('.dne') or network.endswith('.net'))
    with open(network) as f:
        text = f.read()
        clauses = encode_dne(text) if network.endswith('.dne') else encode_net(text)

    if evidence:
        evidence_clauses = encode_inst_evidence(evidence)
        num_clauses = len(evidence_clauses)
        clauses += evidence_clauses
    else:
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
        name = re.findall(r'\nnode (\w+)', f.read())[-1]

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
            if components[5] == name:
                goal_literal = abs(literal)
    weights_line = []
    for literal in range(1, max_literal + 1):
        weights_line += [weights[literal], weights[-literal]]
    encoding = 'c weights ' + ' '.join(weights_line) + '\n'
    if (evidence is None):
        encoding += '-{} 0\n'.format(goal_literal)
    with open(network + '.cnf', 'a') as f:
        f.write(encoding)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Encode Bayesian networks into instances of weighted model counting (WMC)')
    parser.add_argument('network', metavar='network', help='a Bayesian network (in either DNE or NET format)')
    parser.add_argument('encoding', choices=['d02', 'sbk05', 'cd05', 'cd06', 'db20'], help='a WMC encoding')
    parser.add_argument('-e', dest='evidence', help="evidence file (in the INST format)")
    args = parser.parse_args()
    if args.encoding == 'db20':
        encode(args.network, args.evidence)
    else:
        encode_using_ace(args.network, args.evidence, args.encoding)
