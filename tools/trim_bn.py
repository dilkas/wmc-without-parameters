import argparse
import collections
import os
import re

import common

ENDING_RE = {'dne': re.compile(r'\n};'), 'net': re.compile(r'\n}')}
NODE_RE = re.compile(common.NODE_RE)
POTENTIAL_RE = re.compile(common.POTENTIAL_RE)


def mark_ancestors(variable, parents, relevant):
    if relevant[variable]: return
    relevant[variable] = True
    for parent in parents[variable]:
        mark_ancestors(parent, parents, relevant)


def remove_node_info(text, relevant, file_format):
    updated_text = text
    nodes = list(NODE_RE.finditer(text))
    removed_variables = []
    for node in nodes[::-1]:
        variable_name = node.group(1)
        ending = ENDING_RE[file_format].search(text, node.end())
        if not relevant[variable_name]:
            removed_variables.append(variable_name)
            updated_text = (updated_text[:node.start()] +
                            updated_text[ending.end():])

    # Also delete the 'potentials'
    if file_format == 'net':
        for potential in list(POTENTIAL_RE.finditer(updated_text))[::-1]:
            potential_variable = re.search(r'\w+', potential.group(1)).group(0)
            if potential_variable in removed_variables:
                updated_text = (updated_text[:potential.start(0)] +
                                updated_text[potential.end(0):])

    print(' removed {} out of {} variables ({:.2f}%)'.format(
        len(removed_variables), len(nodes), 100 * len(removed_variables) / len(nodes)), flush=True)
    return updated_text


def trim_file(network, evidence=None):
    print(evidence + ':' if evidence else network + ':', end='', flush=True)

    # Mark some of the variables of the Bayesian network as relevant
    bn = common.BayesianNetwork(network)
    relevant = collections.defaultdict(bool)
    if not common.empty_evidence(evidence):
        for variable, _ in common.parse_evidence(evidence):
            mark_ancestors(variable, bn.parents, relevant)
    else:
        mark_ancestors(bn.goal()[0], bn.parents, relevant)

    # Create a new version of the Bayesian network without superfluous variables
    with open(network, encoding=common.FILE_ENCODING) as f:
        text = f.read()
    text = remove_node_info(text, relevant, common.get_file_format(network))
    return text


def trim_directory_with_evidence(input_directory, output_directory):
    files = os.listdir(input_directory)
    for filename in files:
        if filename.endswith('.inst'):
            # Determine the filename for the Bayesian network itself
            potential_bn_filenames = [
                filename[:filename.rindex('.')] + '.dne',
                filename[:filename.rindex('.')] + '.net',
                filename[:filename.rindex('-')] + '.dne',
                filename[:filename.rindex('-')] + '.net'
            ]
            bn_filenames = set(files).intersection(set(potential_bn_filenames))
            assert len(bn_filenames) == 1
            bn_filename = bn_filenames.pop()
            # Write to the new file
            new_contents = trim_file(
                os.path.join(input_directory, bn_filename),
                os.path.join(input_directory, filename))
            new_filename = filename[:filename.rindex('.')] + bn_filename[
                bn_filename.rindex('.'):]
            with open(os.path.join(output_directory, new_filename), 'w') as f:
                f.write(new_contents)


def trim_directory_without_evidence(input_directory, output_directory):
    for filename in os.listdir(input_directory):
        if filename.endswith('.dne') or filename.endswith('.net'):
            new_contents = trim_file(os.path.join(input_directory, filename))
            with open(os.path.join(output_directory, filename), 'w') as f:
                f.write(new_contents)


if __name__ == '__main__':
    trim_directory_with_evidence('data/2004-pgm', 'trimmed_data/2004-pgm/')
    trim_directory_with_evidence('data/2005-ijcai/',
                                 'trimmed_data/2005-ijcai/')
    trim_directory_with_evidence('data/2006-ijar/', 'trimmed_data/2006-ijar/')
    trim_directory_without_evidence('data/DQMR/qmr-100/',
                                    'trimmed_data/DQMR/qmr-100/')
    trim_directory_with_evidence('data/DQMR/qmr-50/',
                                 'trimmed_data/DQMR/qmr-50/')
    trim_directory_with_evidence('data/DQMR/qmr-60/',
                                 'trimmed_data/DQMR/qmr-60/')
    trim_directory_with_evidence('data/DQMR/qmr-70/',
                                 'trimmed_data/DQMR/qmr-70/')
    trim_directory_without_evidence('data/Grid/Ratio_50/',
                                    'trimmed_data/Grid/Ratio_50/')
    trim_directory_without_evidence('data/Grid/Ratio_75/',
                                    'trimmed_data/Grid/Ratio_75/')
    trim_directory_without_evidence('data/Grid/Ratio_90/',
                                    'trimmed_data/Grid/Ratio_90/')
    trim_directory_with_evidence(
        'data/Plan_Recognition/with_evidence/',
        'trimmed_data/Plan_Recognition/with_evidence/')
    trim_directory_without_evidence(
        'data/Plan_Recognition/without_evidence/',
        'trimmed_data/Plan_Recognition/without_evidence/')
