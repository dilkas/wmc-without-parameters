TIMEOUT := 1
MAX_MEMORY_USAGE := 1048576 # in kB

EPSILON := 0.000001
ALGORITHM := deps/ADDMC/counting/addmc
EVALUATE := deps/ace/evaluate
CACHET := deps/cachet/cachet
RUN := ulimit -t $(TIMEOUT) -Sv $(MAX_MEMORY_USAGE) && /usr/bin/time -v
DIRECTORIES := Grid/Ratio_50 Grid/Ratio_75 Grid/Ratio_90 DQMR/qmr-100 DQMR/qmr-50 DQMR/qmr-60 DQMR/qmr-70 Plan_Recognition/without_evidence Plan_Recognition/with_evidence 2004-pgm 2005-ijcai 2006-ijar ../test_data

#all: $(addsuffix /NET_WITH_EVIDENCE,$(wildcard data/2005-ijcai/*.inst))
#all: $(addsuffix /NET_WITH_EVIDENCE,$(wildcard data/2006-ijar/*.inst))
#all: $(addsuffix /NET_WITH_EVIDENCE,$(wildcard data/2004-pgm/*.inst))
#all: $(addsuffix /WITHOUT_EVIDENCE,$(wildcard data/Plan_Recognition/without_evidence/*.dne))
#all: $(addsuffix /DNE_WITH_EVIDENCE,$(wildcard data/Plan_Recognition/with_evidence/*.inst))
#all: $(addsuffix /WITHOUT_EVIDENCE,$(wildcard data/DQMR/qmr-100/*.dne))
all: $(addsuffix /DNE_WITH_EVIDENCE,$(wildcard data/DQMR/qmr-50/*.inst))
#all: $(addsuffix /DNE_WITH_EVIDENCE,$(wildcard data/DQMR/qmr-60/*.inst))
#all: $(addsuffix /DNE_WITH_EVIDENCE,$(wildcard data/DQMR/qmr-70/*.inst))
#all: $(addsuffix /WITHOUT_EVIDENCE,$(wildcard data/Grid/*/*.dne))

#===============================================================================

# The argument is the file format (dne or net)
define run_algorithms_with_evidence
	-cp data/$(shell echo $* | sed "s/-[a-z0-9]\+\.inst/\.$(1)/g") data/$*.$(1)
	-cp data/$(basename $*).$(1) data/$*.$(1)
	-$(RUN) python tools/encode.py data/$*.$(1) -e data/$* cd05 &> results/$*.cd05.new_enc
	-$(RUN) $(ALGORITHM) --cf data/$*.$(1).cnf &> results/$*.cd05.new_inf
	-$(RUN) python tools/encode.py data/$*.$(1) -e data/$* cd06 &> results/$*.cd06.new_enc
	-$(RUN) $(ALGORITHM) --cf data/$*.$(1).cnf &> results/$*.cd06.new_inf
	-$(RUN) python tools/encode.py data/$*.$(1) -e data/$* d02 &> results/$*.d02.new_enc
	-$(RUN) $(ALGORITHM) --cf data/$*.$(1).cnf &> results/$*.d02.new_inf
	-$(RUN) python tools/encode.py data/$*.$(1) -e data/$* sbk05 &> results/$*.sbk05.new_enc
	-$(RUN) $(ALGORITHM) --cf data/$*.$(1).cnf &> results/$*.sbk05.new_inf
	-$(RUN) python tools/encode.py data/$*.$(1) -e data/$* bklm16 &> results/$*.bklm16.new_enc
	-$(RUN) $(ALGORITHM) --wf 4 --cf data/$*.$(1).cnf &> results/$*.bklm16.new_inf
	-$(RUN) python tools/encode.py data/$*.$(1) -e data/$* cw &> results/$*.cw.new_enc
	-$(RUN) $(ALGORITHM) --wf 4 --cf data/$*.$(1).cnf &> results/$*.cw.new_inf
	-$(RUN) python tools/encode.py -l data/$*.$(1) -e data/$* cd05 &> results/$*.cd05.old_enc
	-$(RUN) $(EVALUATE) data/$*.$(1) &> results/$*.cd05.old_inf
	-$(RUN) python tools/encode.py -l data/$*.$(1) -e data/$* cd06 &> results/$*.cd06.old_enc
	-$(RUN) $(EVALUATE) data/$*.$(1) &> results/$*.cd06.old_inf
	-$(RUN) python tools/encode.py -l data/$*.$(1) -e data/$* d02 &> results/$*.d02.old_enc
	-$(RUN) $(EVALUATE) data/$*.$(1) &> results/$*.d02.old_inf
	-$(RUN) python tools/encode.py -l data/$*.$(1) -e data/$* sbk05 &> results/$*.sbk05.old_enc
	-$(RUN) $(CACHET) data/$*.$(1).cnf &> results/$*.sbk05.old_inf
	-$(RUN) python tools/encode.py -l data/$*.$(1) -e data/$* bklm16 &> results/$*.bklm16.old_enc
	-$(RUN) python tools/bklm16_wrapper.py data/$*.$(1) &> results/$*.bklm16.old_inf
endef

# arguments: 1) CNF file, 2) answer file
define test_bklm
	ANSWER=$$($(ALGORITHM) --wf 4 --cf $(1) | awk '/modelCount/ {print $$3}') ; \
	CORRECT_ANSWER=$$(cat $(2)) ; \
	DIFFERENCE=$$(echo "$$ANSWER-$$CORRECT_ANSWER" | bc -l) ; \
	APPROXIMATELY_CORRECT=$$(echo "$${DIFFERENCE#-} < $(EPSILON)" | bc -l) ; \
	if [ "$$APPROXIMATELY_CORRECT" -eq "0" ]; then \
		echo "BKLM16 failed on $(1). The right answer is $$CORRECT_ANSWER, but BKLM16 returned $$ANSWER."; \
		exit 1; \
	fi
endef

data/%/WITHOUT_EVIDENCE:
	-$(RUN) python tools/encode.py data/$* cd05 &> results/$*.cd05.new_enc
	-$(RUN) $(ALGORITHM) --cf data/$*.cnf &> results/$*.cd05.new_inf
	-$(RUN) python tools/encode.py data/$* cd06 &> results/$*.cd06.new_enc
	-$(RUN) $(ALGORITHM) --cf data/$*.cnf &> results/$*.cd06.new_inf
	-$(RUN) python tools/encode.py data/$* d02 &> results/$*.d02.new_enc
	-$(RUN) $(ALGORITHM) --cf data/$*.cnf &> results/$*.d02.new_inf
	-$(RUN) python tools/encode.py data/$* sbk05 &> results/$*.sbk05.new_enc
	-$(RUN) $(ALGORITHM) --cf data/$*.cnf &> results/$*.sbk05.new_inf
	-$(RUN) python tools/encode.py data/$* bklm16 &> results/$*.bklm16.new_enc
	-$(RUN) $(ALGORITHM) --wf 4 --cf data/$*.cnf &> results/$*.bklm16.new_inf
	-$(RUN) python tools/encode.py data/$* cw &> results/$*.cw.new_enc
	-$(RUN) $(ALGORITHM) --wf 4 --cf data/$*.cnf &> results/$*.cw.new_inf
	-$(RUN) python tools/encode.py -l data/$*.$(1) cd05 &> results/$*.cd05.old_enc
	-$(RUN) $(EVALUATE) data/$*.$(1) &> results/$*.cd05.old_inf
	-$(RUN) python tools/encode.py -l data/$*.$(1) cd06 &> results/$*.cd06.old_enc
	-$(RUN) $(EVALUATE) data/$*.$(1) &> results/$*.cd06.old_inf
	-$(RUN) python tools/encode.py -l data/$*.$(1) d02 &> results/$*.d02.old_enc
	-$(RUN) $(EVALUATE) data/$*.$(1) &> results/$*.d02.old_inf
	-$(RUN) python tools/encode.py -l data/$*.$(1) sbk05 &> results/$*.sbk05.old_enc
	-$(RUN) $(CACHET) data/$*.$(1).cnf &> results/$*.sbk05.old_inf
	-$(RUN) python tools/encode.py -l data/$*.$(1) bklm16 &> results/$*.bklm16.old_enc
	-$(RUN) python tools/bklm16_wrapper.py data/$*.$(1) &> results/$*.bklm16.old_inf

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
		rm -f data/$$d/*.uai.* ; \
	done

# cd05 and cd06 are supposed to produce wrong answers
%.test: %.net %.answer %.inst %.inst.answer $(ALGORITHM) tools/encode.py
# NET
	python tools/encode.py $< cw
	$(ALGORITHM) --wf 4 --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "CW failed on $@" && exit 1)
	python tools/encode.py $< d02
	$(ALGORITHM) --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "D02 failed on $@" && exit 1)
	python tools/encode.py $< sbk05
	$(ALGORITHM) --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "SBK05 failed on $@" && exit 1)
	python tools/encode.py $< bklm16
	$(call test_bklm,$<.cnf,$(word 2, $?))
# NET with evidence
	python tools/encode.py $< -e $(word 3, $?) cw
	$(ALGORITHM) --wf 4 --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "CW failed on $@" && exit 1)
	python tools/encode.py $< -e $(word 3, $?) d02
	$(ALGORITHM) --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "D02 failed on $@" && exit 1)
	python tools/encode.py $< -e $(word 3, $?) sbk05
	$(ALGORITHM) --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "SBK05 failed on $@" && exit 1)
	python tools/encode.py $< -e $(word 3, $?) bklm16
	$(call test_bklm,$<.cnf,$(word 4, $?))

%.test: %.dne %.answer %.inst %.inst.answer $(ALGORITHM) tools/encode.py
# DNE
	python tools/encode.py $< cw
	$(ALGORITHM) --wf 4 --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "CW failed on $@" && exit 1)
	python tools/encode.py $< d02
	$(ALGORITHM) --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "D02 failed on $@" && exit 1)
	python tools/encode.py $< sbk05
	$(ALGORITHM) --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "SBK05 failed on $@" && exit 1)
	python tools/encode.py $< bklm16
	$(call test_bklm,$<.cnf,$(word 2, $?))
# DNE with evidence
	python tools/encode.py $< -e $(word 3, $?) cw
	$(ALGORITHM) --wf 4 --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "CW failed on $@" && exit 1)
	python tools/encode.py $< -e $(word 3, $?) d02
	$(ALGORITHM) --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "D02 failed on $@" && exit 1)
	python tools/encode.py $< -e $(word 3, $?) sbk05
	$(ALGORITHM) --cf $<.cnf | awk '/modelCount/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "SBK05 failed on $@" && exit 1)
	python tools/encode.py $< -e $(word 3, $?) bklm16
	$(call test_bklm,$<.cnf,$(word 4, $?))

test: $(addsuffix .test, $(basename $(wildcard test_data/*.inst)))
	@echo "Success, all tests passed."
