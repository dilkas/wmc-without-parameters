"""This script is used for all supported encodings. It implements the cw
encoding and wraps around external encoders Ace and bn2cnf to ensure consistent
support for memory limits, file formats, and to work around some bugs related
to evidence encoding in Ace."""

import argparse
import itertools
import re
import resource
import subprocess
from fractions import Fraction

import common

EPSILON = 0.000001  # For comparing floating-point numbers
SOFT_MEMORY_LIMIT = 0.95  # As a proportion of the hard memory limit

# Commands for various software dependencies
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
    """A bidirectional map between variables of a Bayesian network and literals
    of a Boolean formula"""
    _lit2var = {}
    _var2lit = {}
    next_lit = 1

    def add(self, variable, value, literal=None):
        """Adds a variable-value pair to the collection. If no literal is
        provided, we select the next available literal."""
        if literal is None:
            literal = self.next_lit
        assert literal >= self.next_lit
        self._lit2var[literal] = (variable, value)
        self._var2lit[(variable, value)] = literal
        self.next_lit = literal + 1

    def get_literal(self, variable, value):
        """Get the literal associated with the variable-value pair
        (as a string)."""
        if (variable, value) in self:
            return str(self._var2lit[(variable, value)])
        min_literal = min(lit for lit, (var, val) in self._lit2var.items()
                          if var == variable)
        return '-{}'.format(min_literal)

    def __contains__(self, variable_and_value):
        """Checks if this variable-value pair associated with a literal"""
        return variable_and_value in self._var2lit

    def __len__(self):
        """Returns the number of elements in the collection."""
        return self.next_lit - 1

    def __init__(self, bn=None):
        """Given a Bayesian network, every binary variable is assigned one
        literal, and every variable with n values is assigned n literals.
        Otherwise, the collection is initialised as empty."""
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


def exactly_one_constraint(literals, encoding):
    """Given a list of literals and encoding information, returns a list of
    lines that implement the 'exactly one' constraint on the list of literals
    (that can then be inserted into a CNF or a PB file)."""
    if encoding == 'cw_pb':
        return [
            ' '.join('+1 x{}'.format(literal)
                     for literal in literals) + ' = 1;'
        ]
    return ['{} 0'.format(' '.join(literals))] + [
        '-{} -{} 0'.format(literals[i], literals[j])
        for i in range(len(literals)) for j in range(i + 1, len(literals))
    ]


def bn2cnf(bn, literal_dict, encoding):
    """Transforms a Bayesian network to a list of constraints/clauses. The
    return value is divided into two parts: regular clauses and weights.
    NOTE: This function has nothing to do with the external program with the
    same name."""
    def construct_weights(variable, literal, probability_index,
                          negate_probability):
        clauses = []
        for row in itertools.product(
                *[bn.values[p] for p in bn.parents[variable]]):
            conditions = [
                literal_dict.get_literal(parent, parent_value)
                for parent, parent_value in zip(bn.parents[variable], row)
            ]
            probability = Fraction(bn.probabilities[variable]
                                   [probability_index]).limit_denominator()
            clauses.append('w {} {} {}'.format(
                ' '.join([literal] + conditions), float(probability),
                float(negate_probability(probability))))
            probability_index += len(bn.values[variable])
        return clauses

    clauses = []
    weight_clauses = []
    for variable in bn.parents:
        if len(bn.values[variable]) == 2:
            index, value = bn.goal_value(variable)
            literal = literal_dict.get_literal(variable, value)
            weight_clauses += construct_weights(variable, literal, index,
                                                lambda p: 1 - p)
        else:
            values = [
                literal_dict.get_literal(variable, v)
                for v in bn.values[variable]
            ]
            clauses += exactly_one_constraint(values, encoding)
            for i, value in enumerate(values):
                weight_clauses += construct_weights(variable, value, i,
                                                    lambda p: 1)
    return clauses, weight_clauses


def bn2uai(bn):
    """Represents the Bayesian network using the UAI format. Returns a list of
    string lines that can be written to a file and a list of variables of the
    network, where the index of a variable in this list is the numerical
    representation of the variable in the UAI format."""
    variables = list(bn.parents.keys())  # Fix an order on variables
    parents = [[variables.index(v) for v in bn.parents[variables[variable]]]
               for variable in range(len(variables))]
    probabilities = [
        bn.probabilities[variables[v]] for v in range(len(variables))
    ]

    # The header (the first four lines)
    lines = ['BAYES', str(len(variables))]
    lines.append(' '.join(
        str(len(bn.values[variables[v]])) for v in range(len(variables))))
    lines.append(str(len(variables)))

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
        for key in new_keys:
            lines.append(' '.join(rearranged_probabilities[frozenset(key)]))
    return lines, variables


def encode_single_literal(literal, encoding):
    """Returns a string that encodes the given literal as a clause."""
    if encoding != 'cw_pb':
        return '{} 0'.format(literal)
    return ('1 x{} = 0;'.format(literal[1:])
            if literal.startswith('-') else '1 x{} = 1;'.format(literal))


def new_evidence_file(network_filename, variable, value):
    """Creates a new evidence file for a given goal variable-value pair (and
    returns its filename)."""
    new_filename = network_filename + '.inst'
    with open(new_filename, 'w') as evidence_file:
        evidence_file.write(
            '<?xml version="1.0" encoding="UTF-8"?>\n<instantiation>' +
            '<inst id="{}" value="{}"/>'.format(variable, value) +
            '</instantiation>')
    return new_filename


def encode_weights(weights, max_literal, legacy_mode):
    """Encodes a literal->weight map into either cachet (legacy_mode = True) or
    minic2d (legacy_mode = False) weight format. Returns a list of lines that
    can be inserted into a DIMACS CNF file."""
    if legacy_mode:
        return [
            'w {} {}'.format(
                literal, -1 if abs(float(weights[literal]) - 1) < EPSILON else
                weights[literal]) for literal in range(1, max_literal + 1)
        ]
    return [
        'c weights ' + ' '.join(l for literal in range(1, max_literal + 1)
                                for l in [weights[literal], weights[-literal]])
    ]


def reencode_bn2cnf_weights(weights_filename, legacy_mode):
    """Translates weights---as produced by bn2cnf---to the cachet format (while
    also returning the largest literal found in the weight file)."""
    positive_weights = {}
    negative_weights = {}
    with open(weights_filename) as weights_file:
        for line in weights_file:
            words = line.split()
            assert len(words) == 2
            literal = int(words[0])
            if literal < 0:
                negative_weights[-literal] = words[1]
            else:
                positive_weights[literal] = words[1]

    if legacy_mode:
        weights = []
    else:
        weights = [
            'w {} {} {}'.format(literal, positive_weights[literal],
                                negative_weights[literal])
            if literal in negative_weights else 'w {} {}'.format(
                literal, positive_weights[literal])
            for literal in positive_weights
        ]
    return weights, max(positive_weights)


# ============ Functions primarily responsible for parsing ============


def identify_goal(text, bn_format):
    """Looks at a Bayesian network string to determine which marginal
    probability should be computed. Returns the name of the variable, its chosen
    value, and the index of that value among all the values of the variable."""
    goal_node, goal_node_end = [(i.group(1), i.end())
                                for i in re.finditer(common.NODE_RE, text)][-1]
    values = re.split(
        common.STATE_SPLITTER_RE[bn_format],
        re.search(common.STATES_RE[bn_format], text[goal_node_end:]).group(1))
    goal_value = 'true' if 'true' in values else values[0]
    goal_value_index = values.index(goal_value)
    return goal_node, goal_value, goal_value_index


def parse_bn2cnf_variables_file(variables_filename):
    """Parses the bn2cnf variables file into a
    variable x value |-> list of literals whose conjunction corresponds to value
    map (where each literal is represented by a DIMACS CNF line)."""
    indicators = {}
    with open(variables_filename) as variables_file:
        text = variables_file.read()
    for line in re.finditer(r'(\d+) = (.+)', text):
        variable = line.group(1)
        values = [v.split(', ') for v in line.group(2)[2:-2].split('][')]
        for value in range(len(values)):
            indicators[(int(variable),
                        value)] = [l + ' 0' for l in values[value]]
    return indicators


def parse_lmap(filename, goal_variable, goal_value_index, values):
    """Parses an LMAP file into a map of literal weights, a LiteralDict object,
    the literal that corresponds to the goal variable-value pair, and the
    largest literal found in the file."""
    weights = {}
    max_literal = 0
    literal_dict = LiteralDict()
    for line in open(filename):
        if (line.startswith('cc$I') or line.startswith('cc$C')
                or line.startswith('cc$P')):
            components = line.split('$')
            literal = int(components[2])
            weights[literal] = components[3]
            max_literal = max(max_literal, abs(literal))
            if line.startswith('cc$I'):
                variable = components[5]
                value = int(components[6].rstrip())
                if literal > 0:
                    literal_dict.add(variable, values[variable][value],
                                     literal)
                if variable == goal_variable and value == goal_value_index:
                    goal_literal = literal
    return weights, literal_dict, goal_literal, max_literal


# ============ Functions responsible for running external commands ============


def run(command, memory_limit=None):
    """A wrapper function for running any external program."""
    print('...Running {}...'.format(' '.join(command)), end='')
    if memory_limit:
        mem = int(memory_limit) * 1024**3
        process = subprocess.run(command,
                                 stdout=subprocess.PIPE,
                                 preexec_fn=lambda: resource.setrlimit(
                                     resource.RLIMIT_AS,
                                     (int(SOFT_MEMORY_LIMIT * mem), mem)))
    else:
        process = subprocess.run(command, stdout=subprocess.PIPE)
    print('...OK')
    return process.stdout.decode('utf-8')


def run_bn2cnf(bn, bn_filename, memory_limit):
    """Translates the given Bayesian network to the UAI format, writes it to a
    file, and runs bn2cnf on it. Returns the list with variable ordering, as
    compiled by bn2uai."""
    encoded_clauses, literal_dict = bn2uai(bn)
    with open(bn_filename + '.uai', 'w') as network_file:
        network_file.write('\n'.join(encoded_clauses) + '\n')
    run(
        BN2CNF + [
            '-i', bn_filename + '.uai', '-o', bn_filename + '.cnf', '-w',
            bn_filename + '.uai.weights', '-v', bn_filename + '.uai.variables'
        ], memory_limit)
    return literal_dict


def run_legacy_ace(args, goal_variable, goal_value):
    """Runs the Ace compilation script with the options used for the original
    papers (available in Ace's readme.pdf file)."""
    run(
        ACE_LEGACY[args.encoding] + [
            args.network, '-e',
            new_evidence_file(args.network, goal_variable, goal_value)
            if common.empty_evidence(args.evidence) else args.evidence
        ], args.memory)


# ==================== Final output functions ====================


def write_cnf_file(args, num_variables, clauses, weights):
    """If there is a command-line flag for preprocessing, the function writes
    the CNF file without weights, runs pmc, and writes its output together with
    weights back to the file. Otherwise, it immediately writes the full WMC
    instance to a file."""
    header = 'p cnf {} {}'.format(num_variables, len(clauses))
    filename = args.network + '.cnf'
    if args.preprocess:
        with open(filename, 'w') as cnf_file:
            cnf_file.write('\n'.join([header] + clauses) + '\n')
        output = run(PMC + [filename], args.memory)
        with open(filename, 'w') as cnf_file:
            cnf_file.write(output + '\n'.join(weights) + '\n')
    else:
        with open(filename, 'w') as cnf_file:
            cnf_file.write('\n'.join([header] + clauses + weights) + '\n')


def write_pb_file(args, num_variables, constraints, weights):
    """Combines constraints with weights, adds a header, and writes everything
    to a file."""
    header = '* #variable= {} #constraint= {}\n*'.format(
        num_variables, len(constraints))
    with open(args.network + '.pb', 'w') as pb_file:
        pb_file.write('\n'.join([header] + constraints + weights) + '\n')


# ==================== Main encoding functions ====================


def ace_encoder(args):
    """This function is responsible for the entire encoding process for all
    encodings that use Ace."""
    # Identify the goal
    with open(args.network, encoding=common.FILE_ENCODING) as network_file:
        text = network_file.read()
    bn_format = common.get_file_format(args.network)
    goal_variable, goal_value, goal_value_index = identify_goal(
        text, bn_format)

    if args.legacy and args.encoding != 'sbk05':
        run_legacy_ace(args, goal_variable, goal_value)
        return

    run(ACE + ['-' + args.encoding, args.network], args.memory)

    # Make a variable -> list of values map
    values = {
        node.group(1): re.split(
            common.STATE_SPLITTER_RE[bn_format],
            re.search(common.STATES_RE[bn_format], text[node.end():]).group(1))
        for node in re.finditer(common.NODE_RE, text)
    }

    weights, literal_dict, goal_literal, max_literal = parse_lmap(
        args.network + '.lmap', goal_variable, goal_value_index, values)

    if common.empty_evidence(args.evidence):
        evidence = [encode_single_literal(goal_literal, args.encoding)]
    else:
        evidence = [
            encode_single_literal(literal_dict.get_literal(variable, value),
                                  args.encoding)
            for variable, value in common.parse_evidence(args.evidence)
        ]

    weight_encoding = encode_weights(weights, max_literal, args.legacy)

    with open(args.network + '.cnf') as cnf_file:
        clauses = [
            l.rstrip() for l in cnf_file if l[0].isdigit() or l[0] == '-'
        ]
    write_cnf_file(args, max_literal, clauses + evidence, weight_encoding)


def bn2cnf_encoder(args):
    """This function is responsible for the entire encoding process for the
    bklm16 encoding (that uses the bn2cnf program)."""
    bn = common.BayesianNetwork(args.network)
    literal_dict = run_bn2cnf(bn, args.network, args.memory)
    encoded_weights, max_literal = reencode_bn2cnf_weights(
        args.network + '.uai.weights', args.legacy)
    indicators = parse_bn2cnf_variables_file(args.network + '.uai.variables')

    # Incorporate evidence (or select a goal)
    if not common.empty_evidence(args.evidence):
        encoded_evidence = []
        for variable, value in common.parse_evidence(args.evidence):
            encoded_evidence += indicators[(literal_dict.index(variable),
                                            bn.values[variable].index(value))]
    else:
        # Identify the goal formula
        with open(args.network) as network_file:
            text = network_file.read()
        (goal_variable_string,
         _, goal_value) = identify_goal(text,
                                        common.get_file_format(args.network))
        goal_variable = literal_dict.index(goal_variable_string)
        encoded_evidence = indicators[(goal_variable, goal_value)]

    # Update the number of clauses
    with open(args.network + '.cnf') as cnf_file:
        lines = cnf_file.read().splitlines()

    # Put everything together and write to a file
    clauses = [l.rstrip() for l in lines if l[0].isdigit() or l[0] == '-'
               ] + encoded_evidence
    write_cnf_file(args, max_literal, clauses, encoded_weights)

    if args.legacy:
        run(C2D + ['-in', args.network + '.cnf'], args.memory)


def my_encoder(args):
    """This function is responsible for the entire encoding process for the cw
    encoding (both CNF and PB versions)."""
    bn = common.BayesianNetwork(args.network)
    literal_dict = LiteralDict(bn)
    clauses, weight_clauses = bn2cnf(bn, literal_dict, args.encoding)

    if not common.empty_evidence(args.evidence):
        clauses += [
            encode_single_literal(literal_dict.get_literal(variable, value),
                                  args.encoding)
            for variable, value in common.parse_evidence(args.evidence)
        ]
    else:
        # Add a goal clause if necessary
        literal = literal_dict.get_literal(*bn.goal())
        clauses.append(encode_single_literal(literal, args.encoding))

    if args.encoding == 'cw_pb':
        write_pb_file(args, len(literal_dict), clauses, weight_clauses)
    else:
        write_cnf_file(args, len(literal_dict), clauses, weight_clauses)


def main():
    """Sets up all information about command-line arguments and redirects the
    arguments to one out of three encoder functions."""
    parser = argparse.ArgumentParser(
        description='Encode Bayesian networks into instances of ' +
        'weighted model counting (WMC)')
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
        help='legacy mode, i.e., the encoding is compatible with the ' +
        'original compiler or model counter (and not DPMC or ADDMC)')
    parser.add_argument(
        '-m',
        dest='memory',
        help='the maximum amount of virtual memory available to underlying ' +
        'encoders (in GiB)')
    parser.add_argument('-p',
                        dest='preprocess',
                        action='store_true',
                        help='run a preprocessor (PMC) on the CNF file')
    args = parser.parse_args()

    if args.encoding.startswith('cw'):
        my_encoder(args)
    elif args.encoding == 'bklm16':
        bn2cnf_encoder(args)
    else:
        ace_encoder(args)


if __name__ == '__main__':
    main()
