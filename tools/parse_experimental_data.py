import csv
import glob
import os
import re


def parse(filename):
    with open(filename) as f:
        lines = f.read().splitlines()
    answer = None
    time = None
    for line in lines:
        stripped = line.lstrip()
        if stripped.startswith('Elapsed'):
            # Time
            time_str = line.split()[7]
            colon_i = time_str.index(':')
            time = (60 * int(time_str[:colon_i]) +
                    float(time_str[colon_i + 1:]))
        elif filename.endswith('.new_inf') and line.startswith('* modelCount'):
            answer = line.split()[2]  # ADDMC answer
        elif filename.endswith('.bklm16.old_inf') and line[0].isdigit():
            answer = line  # Query-DNNF answer
        elif (filename.endswith('.sbk05.old_inf')
              and line.startswith('Satisfying')):
            answer = line.split()[2]  # Cachet answer
        elif filename.endswith('.old_inf') and line.startswith('Pr(e) ='):
            # Ace evaluation answer
            try:
                answer = re.match(r'[\d\.eE-]+', line.split()[2]).group(0)
            except AttributeError:
                answer = 'Inf'
    return time, answer


def parse_dir(directory, additional_data={}):
    data = []
    for filename in glob.glob(directory + '*inf'):
        d = additional_data.copy()
        d['inference_time'], d['answer'] = parse(filename)
        d['encoding_time'], _ = parse(filename[:-3] + 'enc')

        parts = filename.split('.')
        instance = (parts[0] if parts[1] in [
            'inst', 'cd05', 'cd06', 'cw', 'sbk05', 'd02'
        ] else parts[0] + '.' + parts[1])
        d['instance'] = instance
        d['novelty'], _ = parts[-1].split('_')
        d['encoding'] = parts[-2]
        data.append(d)
    return data


data = []
data += parse_dir('results/Grid/Ratio_50/', {'dataset': 'Grid-50'})
data += parse_dir('results/Grid/Ratio_75/', {'dataset': 'Grid-75'})
data += parse_dir('results/Grid/Ratio_90/', {'dataset': 'Grid-90'})
data += parse_dir('results/DQMR/qmr-100/', {'dataset': 'DQMR-100'})
data += parse_dir('results/DQMR/qmr-50/', {'dataset': 'DQMR-50'})
data += parse_dir('results/DQMR/qmr-60/', {'dataset': 'DQMR-60'})
data += parse_dir('results/DQMR/qmr-70/', {'dataset': 'DQMR-70'})
data += parse_dir('results/Plan_Recognition/without_evidence/',
                  {'dataset': 'Plan Recognition'})
data += parse_dir('results/Plan_Recognition/with_evidence/',
                  {'dataset': 'Plan Recognition'})
data += parse_dir('results/2004-pgm/', {'dataset': '2004-PGM'})
data += parse_dir('results/2005-ijcai/', {'dataset': '2005-IJCAI'})
data += parse_dir('results/2006-ijar/', {'dataset': '2006-IJAR'})

fieldnames = set()
for d in data:
    fieldnames.update(d.keys())

with open('results/results.csv', 'w', newline='') as csvfile:
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()
    for d in data:
        writer.writerow(d)
