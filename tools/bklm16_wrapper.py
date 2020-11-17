import argparse
import subprocess

parser = argparse.ArgumentParser(
    description='A wrapper for query-dnnf to perform inference on the BKLM16 encoding (compiled to d-DNNF format)')
parser.add_argument('network', metavar='network', help='a Bayesian network')
args = parser.parse_args()

process = subprocess.Popen('./deps/query-dnnf/query-dnnf', stdin=subprocess.PIPE,
                           stdout=subprocess.PIPE)
output, _ = process.communicate(
    'load {}.cnf.nnf\nw {}.uai.weights\nmc'.format(args.network,
                                                   args.network).encode())
output_probability = float(output.decode('utf-8').split()[-1])

multiplier = 1
with open('{}.uai.weights'.format(args.network)) as f:
    for line in f:
        if line.startswith('0 '):
            multiplier = float(line.split()[1])
            break

print(multiplier * output_probability)
