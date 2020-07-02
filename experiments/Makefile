# TODO: increase this before running
TIMEOUT := 1
MAX_MEMORY_USAGE := 1048576 # 1 GB
OUTPUT_DIR := results/temp
ALGORITHM := ulimit -t $(TIMEOUT) -Sv $(MAX_MEMORY_USAGE) && /usr/bin/time -v ./ADDMC/counting/addmc

all: $(addsuffix /WITHOUT_EVIDENCE,$(wildcard data/Grid/*/*.dne))
all: $(addsuffix /WITHOUT_EVIDENCE,$(wildcard data/DQMR/qmr-100/*.dne))
all: $(addsuffix /WITH_EVIDENCE,$(wildcard data/DQMR/qmr-50/*.inst))
all: $(addsuffix /WITH_EVIDENCE,$(wildcard data/DQMR/qmr-60/*.inst))
all: $(addsuffix /WITH_EVIDENCE,$(wildcard data/DQMR/qmr-70/*.inst))

data/%/WITHOUT_EVIDENCE:
	python dne2cnf.py data/$* db20
	-$(ALGORITHM) --wf 4 --cf data/$*.cnf &> $(OUTPUT_DIR)/$*.db20
	python dne2cnf.py data/$* d02
	-$(ALGORITHM) --cf data/$*.cnf &> $(OUTPUT_DIR)/$*.d02
	python dne2cnf.py data/$* sbk05
	-$(ALGORITHM) --cf data/$*.cnf &> $(OUTPUT_DIR)/$*.sbk05
	python dne2cnf.py data/$* cd05
	-$(ALGORITHM) --cf data/$*.cnf &> $(OUTPUT_DIR)/$*.cd05
	python dne2cnf.py data/$* cd06
	-$(ALGORITHM) --cf data/$*.cnf &> $(OUTPUT_DIR)/$*.cd06

data/%/WITH_EVIDENCE:
	cp data/$(shell echo $* | sed "s/-[0-9]\+\.inst/\.dne/g") data/$*.dne
	python dne2cnf.py data/$*.dne -e data/$* db20
	-$(ALGORITHM) --wf 4 --cf data/$*.dne.cnf &> $(OUTPUT_DIR)/$*.db20
	python dne2cnf.py data/$*.dne -e data/$* d02
	-$(ALGORITHM) --cf data/$*.dne.cnf &> $(OUTPUT_DIR)/$*.d02
	python dne2cnf.py data/$*.dne -e data/$* sbk05
	-$(ALGORITHM) --cf data/$*.dne.cnf &> $(OUTPUT_DIR)/$*.sbk05
	python dne2cnf.py data/$*.dne -e data/$* cd05
	-$(ALGORITHM) --cf data/$*.dne.cnf &> $(OUTPUT_DIR)/$*.cd05
	python dne2cnf.py data/$*.dne -e data/$* cd06
	-$(ALGORITHM) --cf data/$*.dne.cnf &> $(OUTPUT_DIR)/$*.cd06

clean:
	rm -f data/Grid/Ratio_50/*.dne.*
	rm -f data/Grid/Ratio_75/*.dne.*
	rm -f data/Grid/Ratio_90/*.dne.*
	rm -f data/DQMR/qmr-100/*.dne.*
	rm -f data/DQMR/qmr-50/*.dne.*
	rm -f data/DQMR/qmr-60/*.dne.*
	rm -f data/DQMR/qmr-70/*.dne.*
	rm -f $(OUTPUT_DIR)/Grid/Ratio_50/*
	rm -f $(OUTPUT_DIR)/Grid/Ratio_75/*
	rm -f $(OUTPUT_DIR)/Grid/Ratio_90/*
	rm -f $(OUTPUT_DIR)/DQMR/qmr-100/*
	rm -f $(OUTPUT_DIR)/DQMR/qmr-50/*
	rm -f $(OUTPUT_DIR)/DQMR/qmr-60/*
	rm -f $(OUTPUT_DIR)/DQMR/qmr-70/*
	rm -f data/Grid/Ratio_50/*.inst.dne
	rm -f data/Grid/Ratio_75/*.inst.dne
	rm -f data/Grid/Ratio_90/*.inst.dne
	rm -f data/DQMR/qmr-100/*.inst.dne
	rm -f data/DQMR/qmr-50/*.inst.dne
	rm -f data/DQMR/qmr-60/*.inst.dne
	rm -f data/DQMR/qmr-70/*.inst.dne
