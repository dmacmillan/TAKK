#!/usr/bin/make -rRf

ifndef sample
error::
	@>&2 echo 'tap: missing parameter `sample`'
endif

SHELL = /bin/bash -e -o pipefail

.DELETE_ON_ERROR:

.ONESHELL:

TAKK_outdir = $(outdir)/TAKK_v$(VERSION)
assembly_outdir = $(TAKK_outdir)/trans-abyss_v$(TRANSABYSS_VERSION)
pavfinder_outdir = $(TAKK_outdir)/pavfinder_v$(PAVFINDER_VERSION)
self_dir := $(dir $(lastword $(MAKEFILE_LIST)))
ifdef ss
	SS = --SS
else
	SS = 
endif

# reads
ifdef reads1_list
	reads1 = $(shell cat $(reads1_list))
endif
ifdef reads2_list
	reads2 = $(shell cat $(reads2_list))
endif

# local /tmp copies of reads1 and reads2
tmp_reads1 = $(addprefix /tmp/, $(notdir $(reads1)))
tmp_reads2 = $(addprefix /tmp/, $(notdir $(reads2)))

ifdef copy_tmp
	input1 = $(tmp_reads1)
	input2 = $(tmp_reads2)
else
	input1 = $(reads1)
	input2 = $(reads2)
endif

prefixes = $(foreach kk,$(k),k$(kk).)
k_contigs = $(foreach kk,$(k),$(assembly_outdir)/k$(kk)/$(sample)-final.fa) 
min_k = $(firstword $(k))
max_k = $(lastword $(k))

DONE : $(TAKK_outdir)/c2g.bam $(TAKK_outdir)/r2c_sorted.bam $(TAKK_outdir)/r2c_sorted.bam.bai $(TAKK_outdir)/kleat/$(sample).KLEAT $(TAKK_outdir)/kleat/$(sample).full.fa.gz $(TAKK_outdir)/kleat/$(sample).utr.fa.gz $(TAKK_outdir)/kallisto/$(sample).full.tsv $(TAKK_outdir)/kallisto/$(sample).full.h5 $(TAKK_outdir)/kallisto/$(sample).utr.tsv $(TAKK_outdir)/kallisto/$(sample).utr.h5
	echo DONE && \
	rm -f $(tmp_reads1) $(tmp_reads2)

#Kallisto
$(TAKK_outdir)/kallisto/$(sample).full.tsv $(TAKK_outdir)/kallisto/$(sample).full.h5 $(TAKK_outdir)/kallisto/$(sample).utr.tsv $(TAKK_outdir)/kallisto/$(sample).utr.h5: $(TAKK_outdir)/kleat/$(sample).full.fa.gz $(TAKK_outdir)/kleat/$(sample).utr.fa.gz
	mkdir -p $(TAKK_outdir)/kallisto && \
	$(KALLISTO_PATH) index -i $(TAKK_outdir)/kallisto/$(sample).full.idx $(TAKK_outdir)/kleat/$(sample).full.fa.gz && \
	$(KALLISTO_PATH) quant -i $(TAKK_outdir)/kallisto/$(sample).full.idx -o $(TAKK_outdir)/kallisto/ <(zcat $(input1)) <(zcat $(input2)) --bias -b 100 -t 12 && \
	mv $(TAKK_outdir)/kallisto/abundance.tsv $(TAKK_outdir)/kallisto/$(sample).full.tsv && \
	mv $(TAKK_outdir)/kallisto/abundance.h5 $(TAKK_outdir)/kallisto/$(sample).full.h5 && \
	mv $(TAKK_outdir)/kallisto/run_info.json $(TAKK_outdir)/kallisto/run_info.json.$(sample).full && \
	$(KALLISTO_PATH) index -i $(TAKK_outdir)/kallisto/$(sample).utr.idx $(TAKK_outdir)/kleat/$(sample).utr.fa.gz && \
	$(KALLISTO_PATH) quant -i $(TAKK_outdir)/kallisto/$(sample).utr.idx -o $(TAKK_outdir)/kallisto/ <(zcat $(input1)) <(zcat $(input2)) --bias -b 100 -t 12 && \
	mv $(TAKK_outdir)/kallisto/abundance.tsv $(TAKK_outdir)/kallisto/$(sample).utr.tsv && \
	mv $(TAKK_outdir)/kallisto/abundance.h5 $(TAKK_outdir)/kallisto/$(sample).utr.h5 && \
	mv $(TAKK_outdir)/kallisto/run_info.json $(TAKK_outdir)/kallisto/run_info.json.$(sample).utr

#fasta generation
$(TAKK_outdir)/kleat/$(sample).full.fa.gz $(TAKK_outdir)/kleat/$(sample).utr.fa.gz: $(TAKK_outdir)/kleat/$(sample).KLEAT
	source $(self_dir)/TAKK_profile.sh && \
	time python /genesis/home/dmacmillan/scripts/python/extract_kleat_utr_sequence.py --kleat $(TAKK_outdir)/kleat/$(sample).KLEAT --genome_fasta $(GENOME_PATH) --gtf $(GENES) --out $(TAKK_outdir)/kleat/$(sample).full.fa && \
	grep -A1 utr $(TAKK_outdir)/kleat/$(sample).full.fa > $(TAKK_outdir)/kleat/$(sample).utr.fa && \
	gzip -9 $(TAKK_outdir)/kleat/$(sample).full.fa && \
	gzip -9 $(TAKK_outdir)/kleat/$(sample).utr.fa

#kleat
$(TAKK_outdir)/kleat/$(sample).KLEAT : $(assembly_outdir)/$(sample)-merged.fa $(TAKK_outdir)/r2c_sorted.bam $(TAKK_outdir)/c2g.bam
	source $(self_dir)/TAKK_profile.sh && \
	time python $(KLEAT_PATH) $(TAKK_outdir)/c2g.bam $(assembly_outdir)/$(sample)-merged.fa $(GENOME_PATH) $(GENES) $(TAKK_outdir)/r2c_sorted.bam $(TAKK_outdir)/kleat/$(sample) -k $(sample) \"$(sample)_cleavage_sites\" -ss

# c2g
$(TAKK_outdir)/c2g.bam : $(assembly_outdir)/$(sample)-merged.fa
	source $(self_dir)/TAKK_profile.sh && \
	time gmap -d $(GENOME) -D $(GMAPDB_PATH) $(assembly_outdir)/$(sample)-merged.fa -t $(NUM_THREADS) -f samse -n 0 -x 10 | samtools view -bhS - -o $(TAKK_outdir)/c2g.bam

# r2c
$(TAKK_outdir)/r2c_sorted.bam $(TAKK_outdir)/r2c_sorted.bam.bai : $(assembly_outdir)/$(sample)-merged.fa $(input1) $(input2)
	source $(self_dir)/TAKK_profile.sh && \
	time bwa index $(assembly_outdir)/$(sample)-merged.fa && \
	time bwa mem -t $(NUM_THREADS) $(assembly_outdir)/$(sample)-merged.fa <(zcat $(input1) $(input2)) | samtools view -bhS - -o $(TAKK_outdir)/r2c.bam && \
	time samtools sort -m $(MAX_MEM) -n $(TAKK_outdir)/r2c.bam $(TAKK_outdir)/r2c_ns && \
	time samtools fixmate $(TAKK_outdir)/r2c_ns.bam $(TAKK_outdir)/r2c_fm.bam && \
	time samtools sort -m $(MAX_MEM) $(TAKK_outdir)/r2c_fm.bam $(TAKK_outdir)/r2c_sorted && \
	time samtools index $(TAKK_outdir)/r2c_sorted.bam && \
	rm $(assembly_outdir)/$(sample)-merged.fa.sa \
		$(assembly_outdir)/$(sample)-merged.fa.amb \
		$(assembly_outdir)/$(sample)-merged.fa.ann \
		$(assembly_outdir)/$(sample)-merged.fa.bwt \
		$(assembly_outdir)/$(sample)-merged.fa.pac \
		$(TAKK_outdir)/r2c.bam \
		$(TAKK_outdir)/r2c_ns.bam \
		$(TAKK_outdir)/r2c_fm.bam

# merge
$(assembly_outdir)/$(sample)-merged.fa : $(k_contigs)
	source $(self_dir)/TAKK_profile.sh && \
	time transabyss-merge $(SS) --threads $(NUM_THREADS) --mink $(min_k) --maxk $(max_k) --prefixes $(prefixes) --length $(readlen) $(k_contigs) --out $(assembly_outdir)/$(sample)-merged.fa --force

# assemble
$(assembly_outdir)/k%/$(sample)-final.fa : $(input1) $(input2)
	source $(self_dir)/TAKK_profile.sh && \
	time transabyss $(SS) --kmer $* --pe $(input1) $(input2) --outdir $(assembly_outdir)/k$* --name $(sample) --threads $(NUM_THREADS);

ifdef copy_tmp
# copy input files to local /tmp
$(tmp_reads1) $(tmp_reads2) : $(reads1) $(reads2)
	time cp $(reads1) $(reads2) /tmp && \
	ls -la $(tmp_reads1) $(tmp_reads2)
endif
