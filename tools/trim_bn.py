import argparse
import collections
import re

import common

def mark_ancestors(variable, parents, relevant):
    if relevant[variable]: return
    relevant[variable] = True
    for parent in parents[variable]:
        mark_ancestors(parent, parents, relevant)


def remove_node_info(text, relevant, file_format):
    updated_text = text
    nodes = list(re.finditer(common.NODE_RE, text))
    removed_count = 0
    for node in nodes[::-1]:
        variable_name = node.group(1)
        ending_re = (re.compile(r'\n};') if file_format == 'dne'
                     else re.compile(r'\n}'))
        ending = ending_re.search(text, node.end())
        if not relevant[variable_name]:
            removed_count += 1
            updated_text = (updated_text[:node.start()] +
                            updated_text[ending.end():])
            if file_format == 'net': # Also delete the 'potential'
                for potential in re.finditer(common.POTENTIAL_RE, updated_text):
                    potential_variable = potential.group(1).split()[0][1:]
                    if potential_variable == variable_name:
                        updated_text = (updated_text[:potential.start(0)] +
                                        updated_text[potential.end(0):])
    print('Removed {} out of {} variables ({:.2f}%)'.format(removed_count, len(nodes), 100 * removed_count / len(nodes)))
    return updated_text


def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(
        description=
        'Trim a Bayesian network by removing variables irrelevant to the query'
    )
    parser.add_argument(
        'network',
        metavar='network',
        help='a Bayesian network (in one of DNE/NET/Hugin formats)')
    parser.add_argument('-e',
                        dest='evidence',
                        help='evidence file (in the INST format)')
    args = parser.parse_args()

    # Mark some of the variables of the Bayesian network as relevant
    bn = common.BayesianNetwork(args.network)
    relevant = collections.defaultdict(bool)
    if args.evidence:
        for variable, _ in common.parse_evidence(args.evidence):
            mark_ancestors(variable, bn.parents, relevant)
    else:
        mark_ancestors(bn.goal()[0], bn.parents, relevant)

    # Create a new version of the Bayesian network without superfluous variables
    with open(args.network, encoding=common.FILE_ENCODING) as f:
        text = f.read()
    text = remove_node_info(text, relevant, common.get_file_format(args.network))
    print(text)  # TODO: what do I do with the updated text?


if __name__ == '__main__':
    main()
