import csv
import os

def parse(filename):
    d = {}
    with open(filename) as f:
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
        if not filename.endswith('.cnf'):
            continue
        d = parse(directory + filename)
        d.update(additional_data)
        d['instance'] = filename
        data.append(d)
    return data

data = []
data += parse_dir('results/sang/Grid/Ratio_50/', {'encoding': 'sang', 'ratio': 50})
data += parse_dir('results/sang/Grid/Ratio_75/', {'encoding': 'sang', 'ratio': 75})
data += parse_dir('results/sang/Grid/Ratio_90/', {'encoding': 'sang', 'ratio': 90})
data += parse_dir('results/conditional/Grid/Ratio_50/', {'encoding': 'conditional', 'ratio': 50})
data += parse_dir('results/conditional/Grid/Ratio_75/', {'encoding': 'conditional', 'ratio': 75})
data += parse_dir('results/conditional/Grid/Ratio_90/', {'encoding': 'conditional', 'ratio': 90})

fieldnames = set()
for d in data:
    fieldnames.update(d.keys())

with open('results/all.csv', 'w', newline='') as csvfile:
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()
    for d in data:
        writer.writerow(d)
