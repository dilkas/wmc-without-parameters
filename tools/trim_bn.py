import argparse
import collections


def mark_ancestors(variable, parents, relevant):
    if relevant[variable]:
        return
    relevant[variable] = True
    for parent in parents[variable]:
        mark_ancestors(parent, parents, relevant)


if __name__ == '__main__':
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

    bn = BayesianNetwork(network)
    relevant = collections.defaultdict(bool)
    if args.evidence:
        pass  # TODO (later): for every piece of evidence, run mark_ancestors()
    else:
        mark_ancestors(bn.goal()[0])
