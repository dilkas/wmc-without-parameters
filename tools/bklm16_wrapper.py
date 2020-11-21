import argparse
import resource
import subprocess

parser = argparse.ArgumentParser(
    description='A wrapper for query-dnnf to perform inference on the BKLM16 encoding (compiled to d-DNNF format)')
parser.add_argument('network', metavar='network', help='a Bayesian network')
parser.add_argument('-m', dest='memory', help='the maximum amount of virtual memory available to underlying encoders (in kiB)')
args = parser.parse_args()

if args.memory:
    process = subprocess.Popen('./deps/query-dnnf/query-dnnf',
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               preexec_fn=lambda:
                               resource.setrlimit(resource.RLIMIT_AS,
                                                  (int(args.memory) * 1024,
                                                   resource.RLIM_INFINITY)))
else:
    process = subprocess.Popen('./deps/query-dnnf/query-dnnf',
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE)

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
