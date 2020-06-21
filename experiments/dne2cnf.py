import itertools
import os
import re

def my_encoding(text):
    names = []
    clauses = []
    def name2int(name):
        return str(names.index(name)+1)
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
    goal = clauses[-1].split(' ')[1]
    return 'p cnf {} {}\n'.format(len(names), 1) + '{} 0\n'.format(goal) + '\n'.join(clauses)

def darwiche_encoding(text):
    next_var_index = 1
    lambda_names = {}
    def get_lambda_index(variable, value):
        index = lambda_names[(variable, value)]
        return str(index + 1)
    def probability_conditions(negation_pattern, parents):
        conditions = []
        for negate, parent in zip(negation_pattern, parents):
            conditions.append(get_lambda_index(parent, 'false' if negate else 'true'))
        return conditions

    clauses = []
    for node in re.finditer(r'\nnode (\w+)', text):
        end_of_name = node.end()
        name = node.group(1)

        states = re.search(r'states = \(([^()]*)\)', text[end_of_name:]).group(1)
        assert(states == 'true, false')
        states = states.split(', ')
        for state in states:
            lambda_names[(name, state)] = next_var_index
            next_var_index += 1
        # Clause (1)
        clauses.append(' '.join([get_lambda_index(name, state) for state in states]) + ' 0')
        # Clause (2)
        for state1, state2 in itertools.combinations(states, 2):
            clauses.append('-{} -{} 0'.format(get_lambda_index(name, state1),
                                              get_lambda_index(name, state2)))

        parents = [s for s in re.search(r'parents = \(([^()]*)\)', text[end_of_name:]).group(1).split(', ')
                   if s != '']
        # Parse only the numbers and discard every other one
        probs_str = re.search(r'probs = ([^;]*);', text[end_of_name:]).group(1)
        probs = [p for p in re.split(r'[, ()\n\t]+', probs_str) if p != ''][0::2]
        assert(len(probs) == 2**len(parents))
        possible_negations = itertools.product([False, True], repeat=len(parents))
        weight_lines = zip(possible_negations, probs)
        for negation_pattern, prob in weight_lines: # for each theta variable
            for value in states:
                conditions = probability_conditions(negation_pattern, parents)
                # Clause (3)
                clauses.append(' '.join([next_var_index, '-' + get_lambda_index(name, value)] +
                                        ['-' + c for c in conditions]) + ' 0')
                # Clause (4)
                clauses.append('-{} {} 0'.format(next_var_index, get_lambda_index(name, value)))
                # Clause (5)
                clauses += ['-{} {} 0'.format(next_var_index, condition) for condition in conditions]
            next_var_index += 1
    goal = get_lambda_index(name, 'true')
    clauses.append('{} 0\n'.format(goal))
    return 'p cnf {} {}\n'.format(len(names), len(clauses)) +  + '\n'.join(clauses)
# TODO: debug: create an example BN and check that all 3 encodings give the same answer
# TODO: add weights
# TODO: I think I also need to add some kind of optimisations
# TODO: those optimisations can be applied to my work as well

# Let's start with the Grid networks. Other datasets require computing all/most
# marginals and it's not clear what the CNF encoding represents.
# Grid/{Dne,Cnf}/{Ratio_50,Ratio_75,Ratio_90}/*
# DQMR/{qmr-100,qmr-50,qmr-60,qmr-70}/*.{dne,cnf} (ignore cnfs that are not coupled with dnes)
# Plan_Recognition/*.{cnf,dne}

input_dir = 'data/Grid/Dne/'
output_dir = 'data/Grid/Cnf2/'
for ratio in ['Ratio_50/', 'Ratio_75/', 'Ratio_90/']:
    for filename in os.listdir(input_dir + ratio):
        if not filename.endswith('.dne'):
            continue
        with open(input_dir + ratio + filename) as f:
            encoding = my_encoding(f.read())
        with open(output_dir + ratio + filename[:filename.rindex('.')] + '-q.cnf', 'w') as f:
            f.write(encoding)
