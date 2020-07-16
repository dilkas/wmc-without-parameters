#!/bin/sh
#$ -N cwmc
#$ -cwd
#$ -pe sharedmem 16
#$ -l h_rt=33:00:00
#$ -l h_vmem=8G

. /etc/profile.d/modules.sh
module load python/3.4.3
module load java/jdk/1.8.0

lscpu > cpuinfo.txt
make -j 16
