TIMEOUT := 1
MAX_MEMORY_USAGE := 1048576 # 1 GB

ALGORITHM := ./ADDMC/counting/addmc
RUN := ulimit -t $(TIMEOUT) -Sv $(MAX_MEMORY_USAGE) && /usr/bin/time -v $(ALGORITHM)
DIRECTORIES = Grid/Ratio_50 Grid/Ratio_75 Grid/Ratio_90 DQMR/qmr-100 DQMR/qmr-50 DQMR/qmr-60 DQMR/qmr-70 Plan_Recognition/without_evidence Plan_Recognition/with_evidence 2004-pgm 2005-ijcai 2006-ijar ../test_data

#all: $(addsuffix /WITHOUT_EVIDENCE,$(wildcard data/Grid/*/*.dne))
#all: $(addsuffix /WITHOUT_EVIDENCE,$(wildcard data/DQMR/qmr-100/*.dne))
#all: $(addsuffix /DNE_WITH_EVIDENCE,$(wildcard data/DQMR/qmr-50/*.inst))
#all: $(addsuffix /DNE_WITH_EVIDENCE,$(wildcard data/DQMR/qmr-60/*.inst))
#all: $(addsuffix /DNE_WITH_EVIDENCE,$(wildcard data/DQMR/qmr-70/*.inst))
#all: $(addsuffix /WITHOUT_EVIDENCE,$(wildcard data/Plan_Recognition/without_evidence/*.dne))
#all: $(addsuffix /DNE_WITH_EVIDENCE,$(wildcard data/Plan_Recognition/with_evidence/*.inst))
#all: $(addsuffix /NET_WITH_EVIDENCE,$(wildcard data/2004-pgm/*.inst))
all: $(addsuffix /NET_WITH_EVIDENCE,$(wildcard data/2005-ijcai/*.inst))
#all: $(addsuffix /NET_WITH_EVIDENCE,$(wildcard data/2006-ijar/*.inst))

#===============================================================================

define run_algorithms_with_evidence
	-cp data/$(shell echo $* | sed "s/-[a-z0-9]\+\.inst/\.$(1)/g") data/$*.$(1)
	-cp data/$(basename $*).$(1) data/$*.$(1)
	python encode.py data/$*.$(1) -e data/$* db20
	-$(RUN) --wf 4 --cf data/$*.$(1).cnf &> results/$*.db20
	python encode.py data/$*.$(1) -e data/$* d02
	-$(RUN) --cf data/$*.$(1).cnf &> results/$*.d02
	python encode.py data/$*.$(1) -e data/$* sbk05
	-$(RUN) --cf data/$*.$(1).cnf &> results/$*.sbk05
	python encode.py data/$*.$(1) -e data/$* cd05
	-$(RUN) --cf data/$*.$(1).cnf &> results/$*.cd05
	python encode.py data/$*.$(1) -e data/$* cd06
	-$(RUN) --cf data/$*.$(1).cnf &> results/$*.cd06
endef

data/%/WITHOUT_EVIDENCE:
	python encode.py data/$* db20
	-$(RUN) --wf 4 --cf data/$*.cnf &> results/$*.db20
	python encode.py data/$* d02
	-$(RUN) --cf data/$*.cnf &> results/$*.d02
	python encode.py data/$* sbk05
	-$(RUN) --cf data/$*.cnf &> results/$*.sbk05
	python encode.py data/$* cd05
	-$(RUN) --cf data/$*.cnf &> results/$*.cd05
	python encode.py data/$* cd06
	-$(RUN) --cf data/$*.cnf &> results/$*.cd06

data/%/DNE_WITH_EVIDENCE:
	$(call run_algorithms_with_evidence,dne)

data/%/NET_WITH_EVIDENCE:
	$(call run_algorithms_with_evidence,net)

#===============================================================================

clean:
	for d in $(DIRECTORIES) ; do \
		rm -f data/$$d/*.dne.* ; \
		rm -f data/$$d/*.net.* ; \
		rm -f data/$$d/*.inst.dne ; \
		rm -f data/$$d/*.inst.net ; \
	done

# cd05 and cd06 are supposed to produce wrong answers
%.test: %.net %.answer %.inst %.inst.answer $(ALGORITHM) encode.py
# NET
	python encode.py $< db20
	$(ALGORITHM) --wf 4 --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "DB20 on $@ failed" && exit 1)
	python encode.py $< d02
	$(ALGORITHM) --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "D02 on $@ failed" && exit 1)
	python encode.py $< sbk05
	$(ALGORITHM) --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "SBK05 $@ failed" && exit 1)
# NET with evidence
	python encode.py $< -e $(word 3, $?) db20
	$(ALGORITHM) --wf 4 --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "DB20 on $@ failed" && exit 1)
	python encode.py $< -e $(word 3, $?) d02
	$(ALGORITHM) --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "D02 on $@ failed" && exit 1)
	python encode.py $< -e $(word 3, $?) sbk05
	$(ALGORITHM) --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "SBK05 $@ failed" && exit 1)

%.test: %.dne %.answer %.inst %.inst.answer $(ALGORITHM) encode.py
# DNE
	python encode.py $< db20
	$(ALGORITHM) --wf 4 --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "DB20 on $@ failed" && exit 1)
	python encode.py $< d02
	$(ALGORITHM) --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "D02 on $@ failed" && exit 1)
	python encode.py $< sbk05
	$(ALGORITHM) --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "SBK05 $@ failed" && exit 1)
# DNE with evidence
	python encode.py $< -e $(word 3, $?) db20
	$(ALGORITHM) --wf 4 --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "DB20 on $@ failed" && exit 1)
	python encode.py $< -e $(word 3, $?) d02
	$(ALGORITHM) --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "D02 on $@ failed" && exit 1)
	python encode.py $< -e $(word 3, $?) sbk05
	$(ALGORITHM) --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "SBK05 $@ failed" && exit 1)

test: $(addsuffix .test, $(basename $(wildcard test_data/*.inst)))
	@echo "Success, all tests passed."
