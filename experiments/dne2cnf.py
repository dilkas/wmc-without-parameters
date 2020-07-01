import itertools
import os
import random
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from optparse import OptionParser

ACE = ['./ace/compile', '-encodeOnly', '-noEclause']
names = []
def name2int(name):
    return str(names.index(name)+1)

def encode_dne(filename):
    with open(filename) as f:
        text = f.read()
    clauses = []
    def probability_conditions(negation_pattern, parents):
        for negate, parent in zip(negation_pattern, parents):
            yield ('-' if negate else '') + name2int(parent)
    for node in re.finditer(r'\nnode (\w+)', text):
        end_of_name = node.end()
        name = node.group(1)
        names.append(name)
        states = re.search(r'states = \(([^()]*)\)', text[end_of_name:]).group(1)
        assert(states == 'true, false')
        parents = [s for s in re.search(r'parents = \(([^()]*)\)', text[end_of_name:]).group(1).split(', ')
                   if s != '']
        # Parse only the numbers and discard every other one
        probs_str = re.search(r'probs = ([^;]*);', text[end_of_name:]).group(1)
        probs = [p for p in re.split(r'[, ()\n\t]+', probs_str) if p != ''][0::2]
        assert(len(probs) == 2**len(parents))
        possible_negations = itertools.product([False, True], repeat=len(parents))
        weight_lines = zip(possible_negations, probs)
        for negation_pattern, prob in weight_lines:
            conditions = list(probability_conditions(negation_pattern, parents))
            clauses.append('w ' + ' '.join([name2int(name)] + conditions + [prob]))
    return clauses

def encode_inst_evidence(filename):
    clauses = []
    for inst in ET.parse(filename).findall('inst'):
        if inst.attrib['value'] == 'true':
            sign = ''
        elif inst.attrib['value'] == 'false':
            sign = '-'
        else:
            raise Exception('non-binary networks are not supported')
        clauses.append(sign + name2int(inst.attrib['id']) + ' 0')
    return clauses

def encode(network, evidence=None):
    clauses = encode_dne(network)
    if evidence:
        evidence_clauses += encode_inst_evidence(evidence)
        num_clauses = len(evidence_clauses)
    else:
        clauses.append(clauses[-1].split(' ')[1] + ' 0')
        num_clauses = 1
    return 'p cnf {} {}\n'.format(len(names), num_clauses) + '\n'.join(clauses) + '\n'

def encode_using_ace(network, evidence=None):
    command = ACE + ['-e', evidence, network] if evidence else ACE + [network]
    subprocess.run(command)
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
    weights_line = []
    for literal in range(1, max_literal + 1):
        weights_line += [weights[literal], weights[-literal]]
    with open(network + '.cnf', 'a') as f:
        f.write('c weights ' + ' '.join(weights_line) + '\n')

if __name__ == '__main__':
    parser = OptionParser('usage: %prog [options] bayesian_network')
    parser.add_option('-e', dest='evidence', help="evidence file (in the 'inst' format)")
    parser.add_option('-a', action = 'store_true', dest='ace', help="use Ace")
    options, args = parser.parse_args()
    if len(args) != 1:
        parser.print_help()
    else:
        encoding = encode_using_ace(args[0], options.evidence) if options.ace else encode(args[0], options.evidence)
        output_filename = args[0] + '.cnf'
#        with open(output_filename, 'w') as f:
#            f.write(encoding)
