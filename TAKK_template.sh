#!/bin/bash
#$ -S /bin/bash
#$ -q all.q
#$ -pe ncpus 12
#$ -l excl=true,mem_free=3.83G,mem_token=3.83G,h_vmem=3.83G
#$ -j y
#$ -V

export NSLOTS=1
source /home/dmacmillan/scripts/bash/TAKK/TAKK_profile.sh
TAK=/home/dmacmillan/scripts/bash/TAKK/TAKK.sh

r1=
r2=
samp=
out=
s=$(zcat ${r1} | head -2 | tail -1)
rlen=${#s}

if [ ${rlen} -eq 100 -o ${rlen} -eq 101 ]; then
    kvals='32 62 92'
elif [ ${rlen} -eq 75 -o ${rlen} -eq 76 ]; then
    kvals='32 52 72'
else
    echo "k values cannot be determined, manual input is required"
    exit 1
fi

${TAK} sample=${samp} k="${kvals}" readlen=${rlen} reads1=${r1} reads2=${r2} outdir=${out}
