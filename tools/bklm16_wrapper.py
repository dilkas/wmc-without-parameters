import argparse
import resource
import subprocess

SOFT_MEMORY_LIMIT = 0.95  # As a proportion of the hard limit

parser = argparse.ArgumentParser(
    description=
    'A wrapper for query-dnnf to perform inference on the BKLM16 encoding (compiled to d-DNNF format)'
)
parser.add_argument('network', metavar='network', help='a Bayesian network')
parser.add_argument(
    '-m',
    dest='memory',
    help='the maximum amount of virtual memory available to query-dnnf (in GiB)'
)
args = parser.parse_args()

if args.memory:
    mem = int(args.memory) * 1024**3
    process = subprocess.Popen('./deps/query-dnnf/query-dnnf',
                               stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE,
                               preexec_fn=lambda: resource.setrlimit(
                                   resource.RLIMIT_AS,
                                   (int(SOFT_MEMORY_LIMIT * mem), mem)))
else:
    process = subprocess.Popen('./deps/query-dnnf/query-dnnf',
                               stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE)

output, _ = process.communicate('load {}.cnf.nnf\nw {}.uai.weights\nmc'.format(
    args.network, args.network).encode())
output_probability = float(output.decode('utf-8').split()[-1])

multiplier = 1
with open('{}.uai.weights'.format(args.network)) as f:
    for line in f:
        if line.startswith('0 '):
            multiplier = float(line.split()[1])
            break

print(multiplier * output_probability)
