import itertools
import os
import random
import re
import sys
import xml.etree.ElementTree as ET
from optparse import OptionParser

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
# TODO: formatting things such as in the line above should be done outside this function
# This should just return a list of clauses (most likely in string form)

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

def encode(network, evidence=None, last_node_as_goal=False):
    clauses = encode_dne(network)
    goal = clauses[-1].split(' ')[1] if last_node_as_goal else name2int(random.choice(names))
    if evidence:
        evidence_clauses += encode_inst_evidence(evidence)
        num_clauses = len(evidence_clauses) + 1
    else:
        num_clauses = 1
    clauses.append(goal + ' 0')
    return 'p cnf {} {}\n'.format(len(names), num_clauses) + '\n'.join(clauses) + '\n'

# Let's start with the Grid networks. Other datasets require computing all/most
# marginals and it's not clear what the CNF encoding represents.
# Grid/{Dne,Cnf}/{Ratio_50,Ratio_75,Ratio_90}/*
# DQMR/{qmr-100,qmr-50,qmr-60,qmr-70}/*.{dne,cnf} (ignore cnfs that are not coupled with dnes)
# Plan_Recognition/*.{cnf,dne}

# directory = 'data/Grid/'
# for ratio in ['Ratio_50/', 'Ratio_75/', 'Ratio_90/']:
#     for filename in os.listdir(directory + ratio):
#         if not filename.endswith('.dne'):
#             continue
#         with open(directory + ratio + filename) as f:
#             encoding = my_encoding(f.read())
#         with open(directory + ratio + filename[:filename.rindex('.')] + '-q.cnf', 'w') as f:
#             f.write(encoding)

if __name__ == '__main__':
    parser = OptionParser('usage: %prog [options] bayesian_network')
    parser.add_option('-e', dest='evidence', help="evidence file (in the 'inst' format)")
    parser.add_option('-g', action='store_true', dest='last_node_as_goal',
                      help='fix the goal as the last node in the Bayesian network')
    options, args = parser.parse_args()
    if len(args) != 1:
        parser.print_help()
    else:
        encoding = encode(args[0], options.evidence, options.last_node_as_goal)
        output_filename = (options.evidence if options.evidence else args[0]) + '.cnf'
        with open(output_filename, 'w') as f:
            f.write(encoding)
