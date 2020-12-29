import csv
import glob
import os
import re


def parse(filename):
    with open(filename) as f:
        lines = f.read().splitlines()
    answer = None
    time = None
    width = None
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
        elif filename.endswith('.new_inf') and line.startswith('s wmc'):
            answer = line.split()[2]  # DPMC answer
        elif filename.endswith('.new_inf') and line.startswith('c seconds'):
            time = line.split()[2]
        elif filename.endswith('.new_inf') and 'with ADD width' in line:
            width = line.split()[-1]
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
    return time, answer, width


def parse_dir(directory, additional_data={}):
    data = []
    for filename in glob.glob(directory + '*inf'):
        d = additional_data.copy()
        d['inference_time'], d['answer'], d['width'] = parse(filename)
        d['encoding_time'], _, _ = parse(filename[:-3] + 'enc')

        parts = filename.split('.')
        instance = (parts[0] if parts[1] in [
            'inst', 'cd05', 'cd06', 'cw', 'sbk05', 'd02'
        ] else parts[0] + '.' + parts[1])
        d['instance'] = instance
        d['novelty'], _ = parts[-1].split('_')
        d['encoding'] = parts[-2]
        data.append(d)
    return data


directories = [
    ('Grid/Ratio_50/', 'Grid-50'),
    ('Grid/Ratio_75/', 'Grid-75'),
    ('Grid/Ratio_90/', 'Grid-90'),
    ('DQMR/qmr-100/', 'DQMR-100'),
    ('DQMR/qmr-50/', 'DQMR-50'),
    ('DQMR/qmr-60/', 'DQMR-60'),
    ('DQMR/qmr-70/', 'DQMR-70'),
    ('Plan_Recognition/without_evidence/', 'Plan Recognition'),
    ('Plan_Recognition/with_evidence/', 'Plan Recognition'),
    ('2004-pgm/', '2004-PGM'),
    ('2005-ijcai/', '2005-IJCAI'),
    ('2006-ijar/', '2006-IJAR'),
]

for type_of_data in ['original', 'trimmed']:
    data = []
    for directory, dataset in directories:
        data += parse_dir(os.path.join('results', type_of_data, directory),
                          {'dataset': dataset})
    fieldnames = set()
    for d in data:
        fieldnames.update(d.keys())
    with open('results/{}_results.csv'.format(type_of_data), 'w',
              newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        for d in data:
            writer.writerow(d)
