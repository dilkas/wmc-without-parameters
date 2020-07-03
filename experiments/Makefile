TIMEOUT := 1
MAX_MEMORY_USAGE := 1048576 # 1 GB

ALGORITHM := ulimit -t $(TIMEOUT) -Sv $(MAX_MEMORY_USAGE) && /usr/bin/time -v ./ADDMC/counting/addmc
DIRECTORIES = Grid/Ratio_50 Grid/Ratio_75 Grid/Ratio_90 DQMR/qmr-100 DQMR/qmr-50 DQMR/qmr-60 DQMR/qmr-70 Plan_Recognition/without_evidence Plan_Recognition/with_evidence 2004-pgm 2005-ijcai 2006-ijar

#all: $(addsuffix /WITHOUT_EVIDENCE,$(wildcard data/Grid/*/*.dne))
#all: $(addsuffix /WITHOUT_EVIDENCE,$(wildcard data/DQMR/qmr-100/*.dne))
#all: $(addsuffix /DNE_WITH_EVIDENCE,$(wildcard data/DQMR/qmr-50/*.inst))
#all: $(addsuffix /DNE_WITH_EVIDENCE,$(wildcard data/DQMR/qmr-60/*.inst))
#all: $(addsuffix /DNE_WITH_EVIDENCE,$(wildcard data/DQMR/qmr-70/*.inst))
#all: $(addsuffix /WITHOUT_EVIDENCE,$(wildcard data/Plan_Recognition/without_evidence/*.dne))
#all: $(addsuffix /DNE_WITH_EVIDENCE,$(wildcard data/Plan_Recognition/with_evidence/*.inst))
all: $(addsuffix /NET_WITH_EVIDENCE,$(wildcard data/2004-pgm/*.inst))
#all: $(addsuffix /NET_WITH_EVIDENCE,$(wildcard data/2005-ijcai/*.inst))
#all: $(addsuffix /NET_WITH_EVIDENCE,$(wildcard data/2006-ijar/*.inst))

#===============================================================================

define run_algorithms_with_evidence
	cp data/$(shell echo $* | sed "s/-[a-z0-9]\+\.inst/\.$(1)/g") data/$*.$(1)
	python encode.py data/$*.$(1) -e data/$* db20
	-$(ALGORITHM) --wf 4 --cf data/$*.$(1).cnf &> results/$*.db20
	python encode.py data/$*.$(1) -e data/$* d02
	-$(ALGORITHM) --cf data/$*.$(1).cnf &> results/$*.d02
	python encode.py data/$*.$(1) -e data/$* sbk05
	-$(ALGORITHM) --cf data/$*.$(1).cnf &> results/$*.sbk05
	python encode.py data/$*.$(1) -e data/$* cd05
	-$(ALGORITHM) --cf data/$*.$(1).cnf &> results/$*.cd05
	python encode.py data/$*.$(1) -e data/$* cd06
	-$(ALGORITHM) --cf data/$*.$(1).cnf &> results/$*.cd06
endef

data/%/WITHOUT_EVIDENCE:
	python encode.py data/$* db20
	-$(ALGORITHM) --wf 4 --cf data/$*.cnf &> results/$*.db20
	python encode.py data/$* d02
	-$(ALGORITHM) --cf data/$*.cnf &> results/$*.d02
	python encode.py data/$* sbk05
	-$(ALGORITHM) --cf data/$*.cnf &> results/$*.sbk05
	python encode.py data/$* cd05
	-$(ALGORITHM) --cf data/$*.cnf &> results/$*.cd05
	python encode.py data/$* cd06
	-$(ALGORITHM) --cf data/$*.cnf &> results/$*.cd06

data/%/DNE_WITH_EVIDENCE:
	$(call run_algorithms_with_evidence,dne)

data/%/NET_WITH_EVIDENCE:
	$(call run_algorithms_with_evidence,net)

clean:
	for d in $(DIRECTORIES) ; do \
		rm -f data/$$d/*.dne.* ; \
		rm -f data/$$d/*.net.* ; \
		rm -f data/$$d/*.inst.dne ; \
		rm -f data/$$d/*.inst.net ; \
	done
