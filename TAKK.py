__version__ = '1.0'

import gzip,os,sys
try:
    import argparse
except ImportError:
    print "You need Python version >= 2.7 to use this script!"
    sys.exit()
from subprocess import call

parser = argparse.ArgumentParser(description='This script will run the TAKK pipeline via submission to the cluster (genesis).')
parser.add_argument('r1', metavar='<r1>', help='The first paired end reads. File format must be *.f[aq].gz')
parser.add_argument('r2', metavar='<r2>', help='The second paired end reads. File format must be *.f[aq].gz')
parser.add_argument('out', metavar='<out>', help='Directory to write output files to. If it does not already exist it will be created.')
parser.add_argument('name', metavar='<name>', help='Name for the sample/job')
parser.add_argument('-profile','--takk_profile', help='The TAKK profile to use', default='/home/dmacmillan/scripts/bash/TAKK/TAKK_profile.sh')
parser.add_argument('-takk','--takk', help='The TAKK script to use', default='/home/dmacmillan/scripts/bash/TAKK/TAKK.sh')
parser.add_argument('-k','--kvalues', help='The k-values to use for the reads, e.g. "32 52 72"')
parser.add_argument('-qsub', action='store_true', help='If enabled, qsub the command immediately')

args = parser.parse_args()

magic_dict = { "\x1f\x8b\x08": "gz" }
max_len = max([len(x) for x in magic_dict])

def fileType(filename):
    f = open(filename,'r')
    file_start = f.read(max_len)
    for magic, filetype in magic_dict.items():
        if file_start.startswith(magic):
            f.close()
            return filetype
    f.close()
    return None

def isFasta(filename):
    f = open(filename, 'r')
    line = f.readline()
    if (line[0] == '>'):
        f.close()
        return True
    f.close()
    return False

ft1 = fileType(args.r1)
ft2 = fileType(args.r2)

if (ft1 != "gz"):
    if not isFasta(args.r1):
        print "File is not fasta format!"
        sys.exit()
if (ft2 != "gz"):
    if not isFasta(args.r2):
        print "File is not fasta format!"
        sys.exit()

readlen,kvals = None,None

if args.kvalues:
    kvals = "'"+args.kvalues+"'"

r1 = gzip.open(args.r1, 'rb')
line = r1.readline()
seq = r1.readline().strip()
readlen = len(seq)

if not kvals:
    if (100 <= readlen <= 101):
        kvals = '\'32 62 92\''
    elif (75 <= readlen <= 76):
        kvals = '\'32 52 72\''
    else:
        print "k values cannot be determined, manual input required"

result = None
output = os.path.abspath(args.out)

result = '''#!/bin/bash
#$ -S /bin/bash
#$ -q all.q
#$ -pe ncpus 12
#$ -l excl=true,mem_free=3.83G,mem_token=3.83G,h_vmem=3.83G
#$ -j y
#$ -V

export NSLOTS=1
'''
result += 'source {}\n\n'.format(args.takk_profile)
result += 'TAKK={}\n'.format(args.takk)
result += 'r1={}\n'.format(os.path.abspath(args.r1))
result += 'r2={}\n'.format(os.path.abspath(args.r2))
result += 'name={}\n'.format(args.name)
result += 'out={}\n'.format(output)
result += 'rlen={}\n'.format(readlen)
result += 'kvals={}\n\n'.format(kvals)
result += '${TAKK} sample=${name} k="${kvals}" readlen=${rlen} reads1=${r1} reads2=${r2} outdir=${out}'

if not os.path.isdir(output):
    os.makedirs(output)

fileout = os.path.join(output,'TAKK_{}'.format(args.name))
f = open(fileout,'w')
f.write(result)
f.close()

if args.qsub:
    call(["qsub", fileout])
