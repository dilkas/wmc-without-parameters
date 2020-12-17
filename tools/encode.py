import argparse
import itertools
import re
import resource
import subprocess
import xml.etree.ElementTree as ET
from fractions import Fraction

import common

EPSILON = 0.000001  # For comparing floating-point numbers
SOFT_MEMORY_LIMIT = 0.95  # As a proportion of the hard limit

# Software dependencies
ACE = ['deps/ace/compile', '-encodeOnly', '-noEclause']
ACE_LEGACY_BASIC = ['deps/ace/compile', '-forceC2d']
ACE_LEGACY = {
    'd02': ACE_LEGACY_BASIC + ['-d02', '-dtHypergraph', '3'],
    'cd05': ACE_LEGACY_BASIC + ['-cd05', '-dtBnOrder'],
    'cd06': ACE_LEGACY_BASIC + ['-cd06', '-dtBnOrder']
}
BN2CNF = ['deps/bn2cnf_linux', '-e', 'LOG', '-s', 'prime']
C2D = ['deps/ace/c2d_linux']
PMC = [
    'deps/pmc_linux', '-vivification', '-eliminateLit', '-litImplied',
    '-iterate=10'
]


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

    def __contains__(self, variable_and_value):
        return variable_and_value in self._var2lit

    def get_literal(self, variable, value):
        if (variable, value) in self:
            return str(self._var2lit[(variable, value)])
        min_literal = min(lit for lit, (var, val) in self._lit2var.items()
                          if var == variable)
        return '-{}'.format(min_literal)

    def __len__(self):
        return self._next_lit - 1

    def __init__(self, bn=None):
        if bn is None:
            return
        for variable in bn.values:
            if len(bn.values[variable]) == 2:
                self.add(
                    variable, 'true' if 'true' in bn.values[variable] else
                    bn.values[variable][0])
            else:
                for value in bn.values[variable]:
                    self.add(variable, value)


def construct_weights(bn, literal_dict, variable, literal, probability_index,
                      negate_probability):
    rows_of_cpt = itertools.product(
        *[bn.values[p] for p in bn.parents[variable]])
    clauses = []
    for row in rows_of_cpt:
        conditions = [
            literal_dict.get_literal(parent, parent_value)
            for parent, parent_value in zip(bn.parents[variable], row)
        ]
        p = Fraction(
            bn.probabilities[variable][probability_index]).limit_denominator()
        clauses.append('w {} {} {}'.format(' '.join([literal] + conditions),
                                           float(p),
                                           float(negate_probability(p))))
        probability_index += len(bn.values[variable])
    return clauses


def generate_clauses(values, encoding):
    if encoding == 'cw_pb':
        return [' '.join('+1 x{}'.format(value) for value in values) + ' = 1;']
    return ['{} 0'.format(' '.join(values))] + [
        '-{} -{} 0'.format(values[i], values[j]) for i in range(len(values))
        for j in range(i + 1, len(values))
    ]


def cpt2cnf(bn, literal_dict, encoding):
    'Transform a Bayesian network to a list of constraints/clauses'
    clauses = []
    weight_clauses = []
    for variable in bn.parents:
        if len(bn.values[variable]) == 2:
            index, value = bn.goal_value(variable)
            literal = literal_dict.get_literal(variable, value)
            weight_clauses += construct_weights(bn, literal_dict, variable,
                                                literal, index,
                                                lambda p: 1 - p)
        else:
            values = [
                literal_dict.get_literal(variable, v)
                for v in bn.values[variable]
            ]
            clauses += generate_clauses(values, encoding)
            for i, value in enumerate(values):
                weight_clauses += construct_weights(bn, literal_dict, variable,
                                                    value, i, lambda p: 1)
    return clauses, weight_clauses


def cpt2uai(bn):
    variables = list(bn.parents.keys())  # Fix an order on variables
    parents = [[variables.index(v) for v in bn.parents[variables[variable]]]
               for variable in range(len(variables))]
    probabilities = [
        bn.probabilities[variables[v]] for v in range(len(variables))
    ]

    # The first four lines
    lines = [
        'BAYES',
        str(len(variables)), ' '.join(
            str(len(bn.values[variables[v]])) for v in range(len(variables))),
        str(len(variables))
    ]

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
        keys = itertools.product(*[[(p, v) for v in bn.values[variables[p]]]
                                   for p in parents[variable]])
        rearranged_probabilities = {}
        num_values = len(bn.values[variables[variable]])
        for i, key in enumerate(keys):
            first_index = i * num_values
            last_index = (i + 1) * num_values
            rearranged_probabilities[frozenset(
                key)] = probabilities[variable][first_index:last_index]
        new_keys = itertools.product(*[[(p, v)
                                        for v in bn.values[variables[p]]]
                                       for p in sorted(parents[variable])])
        lines += [
            ' '.join(rearranged_probabilities[frozenset(key)])
            for key in new_keys
        ]
    return lines, variables


def encode_inst_evidence(values,
                         literal_dict,
                         filename,
                         encoding,
                         indicators=None,
                         variables_map=None):
    if filename is None:
        return []
    instantiations = ET.parse(filename).findall('inst')
    if indicators is None:
        return [
            format_goal(
                literal_dict.get_literal(inst.attrib['id'],
                                         inst.attrib['value']), encoding)
            for inst in instantiations
        ]
    evidence = []
    for inst in instantiations:
        variable = variables_map.index(inst.attrib['id'])
        value = values[inst.attrib['id']].index(inst.attrib['value'])
        evidence += indicators[(variable, value)]
    return evidence


def evidence_file_is_empty(evidence_file):
    return evidence_file is None or ET.parse(evidence_file).find(
        'inst') is None


def format_goal(literal, encoding):
    if encoding == 'cw_pb':
        return ('1 x{} = 0;'.format(literal[1:])
                if literal.startswith('-') else '1 x{} = 1;'.format(literal))
    return '{} 0'.format(literal)


def encode_cnf(args):
    bn = common.BayesianNetwork(args.network)
    literal_dict = LiteralDict(bn)
    clauses, weight_clauses = cpt2cnf(bn, literal_dict, args.encoding)

    evidence_clauses = encode_inst_evidence(bn.values, literal_dict,
                                            args.evidence, args.encoding)
    if evidence_clauses:
        clauses += evidence_clauses
    else:
        # Add a goal clause if necessary
        literal = literal_dict.get_literal(*bn.goal())
        clauses.append(format_goal(literal, args.encoding))

    if args.encoding == 'cw_pb':
        output_pb(args, len(literal_dict), clauses, weight_clauses)
    else:
        output_cnf(args, len(literal_dict), clauses, weight_clauses)


def identify_goal(text, mode):
    'Which marginal probability should we compute?'
    goal_node, goal_node_end = [(i.group(1), i.end())
                                for i in re.finditer(common.NODE_RE, text)][-1]
    values = re.split(
        common.STATE_SPLITTER_RE[mode],
        re.search(common.STATES_RE[mode], text[goal_node_end:]).group(1))
    goal_value = 'true' if 'true' in values else values[0]
    goal_value_index = values.index(goal_value)
    return goal_node, goal_value_index, goal_value


def new_evidence_file(network_filename, variable, value):
    'Create a new evidence file for a goal variable and value'
    new_filename = network_filename + '.inst'
    with open(new_filename, 'w') as f:
        f.write(
            '<?xml version="1.0" encoding="UTF-8"?>\n<instantiation><inst id="{}" value="{}"/></instantiation>'
            .format(variable, value))
    return new_filename


def run(command, memory_limit=None):
    print('...Running {}...'.format(' '.join(command)), end='')
    if memory_limit:
        mem = int(memory_limit) * 1024**3
        process = subprocess.run(command,
                                 stdout=subprocess.PIPE,
                                 preexec_fn=lambda: resource.setrlimit(
                                     resource.rlimit_as,
                                     (int(SOFT_MEMORY_LIMIT * mem), mem)))
    else:
        process = subprocess.run(command, stdout=subprocess.PIPE)
    print('...OK')
    return process.stdout.decode('utf-8')


def encode_using_ace(args):
    'The main function behind encoding using ace'
    # Identify the goal
    with open(args.network, encoding='ISO-8859-1') as f:
        text = f.read()
    mode = common.get_file_format(args.network)
    goal_node, goal_value_index, goal_value = identify_goal(text, mode)

    if args.legacy and args.encoding != 'sbk05':
        run(
            ACE_LEGACY[args.encoding] + [
                args.network, '-e',
                new_evidence_file(args.network, goal_node, goal_value)
                if evidence_file_is_empty(args.evidence) else args.evidence
            ], args.memory)
        return

    run(ACE + ['-' + args.encoding, args.network], args.memory)

    # Make a variable -> list of values map
    values = {
        node.group(1):
        re.split(common.STATE_SPLITTER_RE[mode],
                 re.search(common.STATES_RE[mode], text[node.end():]).group(1))
        for node in re.finditer(common.NODE_RE, text)
    }

    # Move weights from the LMAP file to the CNF file
    # (and convert the goal to a literal)
    weights = {}
    max_literal = 0
    literal_dict = LiteralDict()
    for line in open(args.network + '.lmap'):
        if (line.startswith('cc$I') or line.startswith('cc$C')
                or line.startswith('cc$P')):
            components = line.split('$')
            literal = int(components[2])
            weight = components[3]
            weights[literal] = weight
            max_literal = max(max_literal, abs(literal))
            if line.startswith('cc$I'):
                variable = components[5]
                value = int(components[6].rstrip())
                if literal > 0:
                    literal_dict.add_literal(variable, values[variable][value],
                                             literal)
                if variable == goal_node and value == goal_value_index:
                    goal_literal = literal

    evidence = (['{} 0'.format(goal_literal)] if evidence_file_is_empty(
        args.evidence) else encode_inst_evidence(values, literal_dict,
                                                 args.evidence, args.encoding))

    if args.legacy:
        weight_encoding = [
            'w {} {}'.format(
                literal, -1 if abs(float(weights[literal]) - 1) < EPSILON else
                weights[literal]) for literal in range(1, max_literal + 1)
        ]
    else:
        weight_encoding = [
            'c weights ' +
            ' '.join(l for literal in range(1, max_literal + 1)
                     for l in [weights[literal], weights[-literal]])
        ]

    with open(args.network + '.cnf') as f:
        lines = f.readlines()
        clauses = [l.rstrip() for l in lines if l[0].isdigit() or l[0] == '-']
    output_cnf(args, max_literal, clauses + evidence, weight_encoding)


def encode_using_bn2cnf(args):
    'Translate the Bayesian network to the UAI format and run the encoder'
    bn = common.BayesianNetwork(args.network)
    literal_dict = LiteralDict(bn)
    encoded_clauses, literal_dict = cpt2uai(bn)

    uai_filename = args.network + '.uai'
    cnf_filename = args.network + '.cnf'
    weights_filename = uai_filename + '.weights'
    variables_filename = uai_filename + '.variables'
    with open(uai_filename, 'w') as f:
        f.write('\n'.join(encoded_clauses) + '\n')
    run(
        BN2CNF + [
            '-i', uai_filename, '-o', cnf_filename, '-w', weights_filename,
            '-v', variables_filename
        ], args.memory)

    # Translate weights to the right format
    if args.legacy:
        encoded_weights = []
    else:
        positive_weights = {}
        negative_weights = {}
        with open(weights_filename) as f:
            for line in f:
                words = line.split()
                assert len(words) == 2
                literal = int(words[0])
                if literal < 0:
                    negative_weights[-literal] = words[1]
                else:
                    positive_weights[literal] = words[1]

        encoded_weights = [
            'w {} {} {}'.format(literal, positive_weights[literal],
                                negative_weights[literal])
            if literal in negative_weights else 'w {} {}'.format(
                literal, positive_weights[literal])
            for literal in positive_weights
        ]

    # Map (variable, value) pairs to CNF formulas
    # (as lists of lines in DIMACS syntax)
    indicators = {}
    with open(variables_filename) as f:
        text = f.read()
    for line in re.finditer(r'(\d+) = (.+)', text):
        variable = line.group(1)
        values = [v.split(', ') for v in line.group(2)[2:-2].split('][')]
        for value in range(len(values)):
            indicators[(int(variable),
                        value)] = [l + ' 0' for l in values[value]]

    # Incorporate evidence (or select a goal)
    if not evidence_file_is_empty(args.evidence):
        encoded_evidence = encode_inst_evidence(bn.values, literal_dict,
                                                args.evidence, args.encoding,
                                                indicators, literal_dict)
    else:
        # Identify the goal formula
        with open(args.network) as f:
            text = f.read()
        (goal_variable_string, goal_value,
         _) = identify_goal(text, common.get_file_format(args.network))
        goal_variable = literal_dict.index(goal_variable_string)
        encoded_evidence = indicators[(goal_variable, goal_value)]

    # Update the number of clauses
    with open(cnf_filename) as f:
        lines = f.read().splitlines()

    # Put everything together and write to a file
    clauses = [l.rstrip() for l in lines if l[0].isdigit() or l[0] == '-'
               ] + encoded_evidence
    output_cnf(args, max(positive_weights), clauses, encoded_weights)

    if args.legacy:
        run(C2D + ['-in', cnf_filename], args.memory)


def output_cnf(args, num_variables, clauses, weights):
    header = 'p cnf {} {}'.format(num_variables, len(clauses))
    filename = args.network + '.cnf'
    if args.preprocess:
        with open(filename, 'w') as f:
            f.write('\n'.join([header] + clauses) + '\n')
        output = run(PMC + [filename], args.memory)
        with open(filename, 'w') as f:
            f.write(output + '\n'.join(weights) + '\n')
    else:
        with open(filename, 'w') as f:
            f.write('\n'.join([header] + clauses + weights) + '\n')


def output_pb(args, num_variables, constraints, weights):
    header = '* #variable= {} #constraint= {}\n*'.format(
        num_variables, len(constraints))
    filename = args.network + '.pb'
    with open(filename, 'w') as f:
        f.write('\n'.join([header] + constraints + weights) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=
        'Encode Bayesian networks into instances of weighted model counting (WMC)'
    )
    parser.add_argument(
        'network',
        metavar='network',
        help='a Bayesian network (in one of DNE/NET/Hugin formats)')
    parser.add_argument(
        'encoding',
        choices=['bklm16', 'cd05', 'cd06', 'cw', 'cw_pb', 'd02', 'sbk05'],
        help='choose a WMC encoding')
    parser.add_argument('-e',
                        dest='evidence',
                        help='evidence file (in the INST format)')
    parser.add_argument(
        '-l',
        dest='legacy',
        action='store_true',
        help=
        'legacy mode, i.e., the encoding is compatible with the original compiler or model counter (and not ADDMC)'
    )
    parser.add_argument(
        '-m',
        dest='memory',
        help=
        "the maximum amount of virtual memory available to underlying encoders (in GiB)"
    )
    parser.add_argument('-p',
                        dest='preprocess',
                        action='store_true',
                        help='run a preprocessor (PMC) on the CNF file')
    args = parser.parse_args()

    if args.encoding.startswith('cw'):
        encode_cnf(args)
    elif args.encoding == 'bklm16':
        encode_using_bn2cnf(args)
    else:
        encode_using_ace(args)
