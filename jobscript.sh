#!/bin/sh
#$ -N cwmc
#$ -cwd
#$ -pe sharedmem 16
#$ -l h_rt=70:00:00
#$ -l h_vmem=32G

. /etc/profile.d/modules.sh
module load java/jdk/1.8.0
module load roslin/python/3.8.1
module load phys/compilers/gcc/10.2.0
module load singularity/3.5.3

lscpu > cpuinfo.txt
make -j 16
