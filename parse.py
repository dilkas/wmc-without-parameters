import csv
import os

def parse(filename):
    d = {}
    with open(filename) as f:
        if filename.endswith('.encoding'):
            for line in f:
                stripped = line.lstrip()
                if stripped.startswith('Elapsed'):
                    time_str = line.split()[7]
                    colon_i = time_str.index(':')
                    d['time'] = (60 * int(time_str[:colon_i]) +
                                 float(time_str[colon_i+1:]))
                if stripped.startswith('Maximum'):
                    d['memory'] = line.split()[5]
        else:
            for line in f:
                if line.startswith('* modelCount'):
                    d['answer'] = line.split()[2]
                if line.startswith('* seconds'):
                    d['time'] = line.split()[2]
                if line.lstrip().startswith('Maximum'):
                    d['memory'] = line.split()[5]
        return d

def parse_dir(directory, additional_data = {}):
    data = []
    for filename in os.listdir(directory):
        d = parse(directory + filename)
        d.update(additional_data)
        parts = filename.split('.')
        instance = (parts[0] if parts[1] in ['inst', 'cd05', 'cd06',
                                             'cw', 'sbk05', 'd02']
                    else parts[0] + '.' + parts[1])
        d['instance'] = directory + instance
        if filename.endswith('.encoding'):
            filename = filename[:-len('.encoding')]
            d['stage'] = 'encoding'
        else:
            d['stage'] = 'inference'
        d['encoding'] = filename[filename.rindex('.')+1:]
        data.append(d)
    return data

data = []
#data += parse_dir('results/Grid/Ratio_50/', {'dataset': 'Grid-50'})
#data += parse_dir('results/Grid/Ratio_75/', {'dataset': 'Grid-75'})
#data += parse_dir('results/Grid/Ratio_90/', {'dataset': 'Grid-90'})
#data += parse_dir('results/DQMR/qmr-100/', {'dataset': 'DQMR-100'})
data += parse_dir('results/DQMR/qmr-50/', {'dataset': 'DQMR-50'})
#data += parse_dir('results/DQMR/qmr-60/', {'dataset': 'DQMR-60'})
#data += parse_dir('results/DQMR/qmr-70/', {'dataset': 'DQMR-70'})
#data += parse_dir('results/Plan_Recognition/without_evidence/', {'dataset': 'Plan Recognition'})
#data += parse_dir('results/Plan_Recognition/with_evidence/', {'dataset': 'Plan Recognition'})
#data += parse_dir('results/2004-pgm/', {'dataset': '2004-PGM'})
#data += parse_dir('results/2005-ijcai/', {'dataset': '2005-IJCAI'})
#data += parse_dir('results/2006-ijar/', {'dataset': '2006-IJAR'})

fieldnames = set()
for d in data:
    fieldnames.update(d.keys())

with open('results.csv', 'w', newline='') as csvfile:
    writer = csv.DictWriter(csvfile, fieldnames=['dataset', 'stage', 'encoding',
                                                 'time', 'answer', 'instance',
                                                 'memory'])
    writer.writeheader()
    for d in data:
        writer.writerow(d)
