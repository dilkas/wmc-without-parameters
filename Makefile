TIMEOUT := 100
MAX_MEMORY = 32 # in GB
MAX_MEMORY_KB = 31876710 # 95% of MAX_MEMORY
EPSILON := 0.000001

ALGORITHM := deps/DPMC/common/addmc # Keeping this around for tests
EVALUATE := deps/ace/evaluate
CACHET := deps/cachet/cachet
HTD := deps/DPMC/lg/solvers/htd-master/bin/htd_main --opt width --iterations 0 --strategy challenge --print-progress --preprocessing full --output width
LG := deps/DPMC/lg/build/lg \"deps/DPMC/lg/solvers/htd-master/bin/htd_main --opt width --iterations 1 --strategy challenge --print-progress --preprocessing full\"
DPMC := deps/DPMC/DMC/dmc --jf=- --pf=1e-3 --jw=$(TIMEOUT)

LIMIT := ulimit -t $(TIMEOUT) -Sv $(MAX_MEMORY_KB)
RUN := $(LIMIT) && /usr/bin/time -v
ENCODE := ulimit -t $(TIMEOUT) && /usr/bin/time -v

DIRECTORIES := Grid/Ratio_50 Grid/Ratio_75 Grid/Ratio_90 DQMR/qmr-100 DQMR/qmr-50 DQMR/qmr-60 DQMR/qmr-70 Plan_Recognition/without_evidence Plan_Recognition/with_evidence 2004-pgm 2005-ijcai 2006-ijar ../../test_data

#all: $(addsuffix /NET_WITH_EVIDENCE,$(wildcard data/original/2005-ijcai/*.inst))
#all: $(addsuffix /NET_WITH_EVIDENCE,$(wildcard data/original/2006-ijar/*.inst))
#all: $(addsuffix /NET_WITH_EVIDENCE,$(wildcard data/original/2004-pgm/*.inst))
#all: $(addsuffix /WITHOUT_EVIDENCE,$(wildcard data/original/Plan_Recognition/without_evidence/*.dne))
#all: $(addsuffix /DNE_WITH_EVIDENCE,$(wildcard data/original/Plan_Recognition/with_evidence/*.inst))
#all: $(addsuffix /WITHOUT_EVIDENCE,$(wildcard data/original/DQMR/qmr-100/*.dne))
#all: $(addsuffix /DNE_WITH_EVIDENCE,$(wildcard data/original/DQMR/qmr-50/*.inst))
#all: $(addsuffix /DNE_WITH_EVIDENCE,$(wildcard data/original/DQMR/qmr-60/*.inst))
#all: $(addsuffix /DNE_WITH_EVIDENCE,$(wildcard data/original/DQMR/qmr-70/*.inst))
#all: $(addsuffix /WITHOUT_EVIDENCE,$(wildcard data/original/Grid/*/*.dne))

#all: $(addsuffix /TREEWIDTH,$(wildcard data/original/2005-ijcai/*.net))
#all: $(addsuffix /TREEWIDTH,$(wildcard data/original/2006-ijar/*.net))
#all: $(addsuffix /TREEWIDTH,$(wildcard data/original/2004-pgm/*.net))
#all: $(addsuffix /TREEWIDTH,$(wildcard data/original/Plan_Recognition/without_evidence/*.dne))
#all: $(addsuffix /TREEWIDTH,$(wildcard data/original/Plan_Recognition/with_evidence/*.dne))
#all: $(addsuffix /TREEWIDTH,$(wildcard data/original/DQMR/qmr-100/*.dne))
all: $(addsuffix /TREEWIDTH,$(wildcard data/original/DQMR/qmr-50/*.dne))
#all: $(addsuffix /TREEWIDTH,$(wildcard data/original/DQMR/qmr-60/*.dne))
#all: $(addsuffix /TREEWIDTH,$(wildcard data/original/DQMR/qmr-70/*.dne))
#all: $(addsuffix /TREEWIDTH,$(wildcard data/original/Grid/*/*.dne))

#===============================================================================

# Arguments: 1) CNF file, 2) weight format number, 3) (most of the) results filename
define run_dpmc
	cnf="data/$(1)" && $(LIMIT) && /usr/bin/time -v -f "%es" bash -c "$(LG) < $$cnf | $(DPMC) --cf=$$cnf --wf $(2)" &> results/$(3).new_inf
endef

# The argument is the file format (dne or net)
define run_algorithms_with_evidence
	-cp data/original/$(shell echo $* | sed "s/-[a-z0-9]\+\.inst/\.$(1)/g") data/original/$*.$(1)
	-cp data/original/$(basename $*).$(1) data/original/$*.$(1)
	-$(ENCODE) python tools/encode.py data/original/$*.$(1) -e data/original/$* cd05 -m $(MAX_MEMORY) &> results/original/$*.cd05.new_enc
	-$(call run_dpmc,original/$*.$(1).cnf,2,original/$*.cd05)
	-$(ENCODE) python tools/encode.py data/original/$*.$(1) -e data/original/$* cd06 -m $(MAX_MEMORY) &> results/original/$*.cd06.new_enc
	-$(call run_dpmc,original/$*.$(1).cnf,2,original/$*.cd06)
	-$(ENCODE) python tools/encode.py data/original/$*.$(1) -e data/original/$* d02 -m $(MAX_MEMORY) &> results/original/$*.d02.new_enc
	-$(call run_dpmc,original/$*.$(1).cnf,2,original/$*.d02)
	-$(ENCODE) python tools/encode.py data/original/$*.$(1) -e data/original/$* sbk05 -m $(MAX_MEMORY) &> results/original/$*.sbk05.new_enc
	-$(call run_dpmc,original/$*.$(1).cnf,2,original/$*.sbk05)
	-$(ENCODE) python tools/encode.py data/original/$*.$(1) -e data/original/$* bklm16 -m $(MAX_MEMORY) &> results/original/$*.bklm16.new_enc
	-$(call run_dpmc,original/$*.$(1).cnf,2,original/$*.bklm16)
	-$(ENCODE) python tools/encode.py data/original/$*.$(1) -e data/original/$* cw -m $(MAX_MEMORY) &> results/original/$*.cw.new_enc
	-$(call run_dpmc,original/$*.$(1).cnf,5,original/$*.cw)
	-$(ENCODE) python tools/encode.py -l data/original/$*.$(1) -e data/original/$* cd05 -m $(MAX_MEMORY) &> results/original/$*.cd05.old_enc
	-$(RUN) $(EVALUATE) data/original/$*.$(1) &> results/original/$*.cd05.old_inf
	-$(ENCODE) python tools/encode.py -l data/original/$*.$(1) -e data/original/$* cd06 -m $(MAX_MEMORY) &> results/original/$*.cd06.old_enc
	-$(RUN) $(EVALUATE) data/original/$*.$(1) &> results/original/$*.cd06.old_inf
	-$(ENCODE) python tools/encode.py -l data/original/$*.$(1) -e data/original/$* d02 -m $(MAX_MEMORY) &> results/original/$*.d02.old_enc
	-$(RUN) $(EVALUATE) data/original/$*.$(1) &> results/original/$*.d02.old_inf
	-$(ENCODE) python tools/encode.py -l data/original/$*.$(1) -e data/original/$* sbk05 -m $(MAX_MEMORY) &> results/original/$*.sbk05.old_enc
	-$(RUN) $(CACHET) data/original/$*.$(1).cnf &> results/original/$*.sbk05.old_inf
	-$(ENCODE) python tools/encode.py -l data/original/$*.$(1) -e data/original/$* bklm16 -m $(MAX_MEMORY) &> results/original/$*.bklm16.old_enc
	-$(ENCODE) python tools/bklm16_wrapper.py data/original/$*.$(1) -m $(MAX_MEMORY) &> results/original/$*.bklm16.old_inf
endef

data/original/%/WITHOUT_EVIDENCE:
	-$(ENCODE) python tools/encode.py data/original/$* cd05 -m $(MAX_MEMORY) &> results/original/$*.cd05.new_enc
	-$(call run_dpmc,original/$*.cnf,2,original/$*.cd05)
	-$(ENCODE) python tools/encode.py data/original/$* cd06 -m $(MAX_MEMORY) &> results/original/$*.cd06.new_enc
	-$(call run_dpmc,original/$*.cnf,2,original/$*.cd06)
	-$(ENCODE) python tools/encode.py data/original/$* d02 -m $(MAX_MEMORY) &> results/original/$*.d02.new_enc
	-$(call run_dpmc,original/$*.cnf,2,original/$*.d02)
	-$(ENCODE) python tools/encode.py data/original/$* sbk05 -m $(MAX_MEMORY) &> results/original/$*.sbk05.new_enc
	-$(call run_dpmc,original/$*.cnf,2,original/$*.sbk05)
	-$(ENCODE) python tools/encode.py data/original/$* bklm16 -m $(MAX_MEMORY) &> results/original/$*.bklm16.new_enc
	-$(call run_dpmc,original/$*.cnf,2,original/$*.bklm16)
	-$(ENCODE) python tools/encode.py data/original/$* cw -m $(MAX_MEMORY) &> results/original/$*.cw.new_enc
	-$(call run_dpmc,original/$*.cnf,5,original/$*.cw)
	-$(ENCODE) python tools/encode.py -l data/original/$* cd05 -m $(MAX_MEMORY) &> results/original/$*.cd05.old_enc
	-$(RUN) $(EVALUATE) data/original/$* &> results/original/$*.cd05.old_inf
	-$(ENCODE) python tools/encode.py -l data/original/$* cd06 -m $(MAX_MEMORY) &> results/original/$*.cd06.old_enc
	-$(RUN) $(EVALUATE) data/original/$* &> results/original/$*.cd06.old_inf
	-$(ENCODE) python tools/encode.py -l data/original/$* d02 -m $(MAX_MEMORY) &> results/original/$*.d02.old_enc
	-$(RUN) $(EVALUATE) data/original/$* &> results/original/$*.d02.old_inf
	-$(ENCODE) python tools/encode.py -l data/original/$* sbk05 -m $(MAX_MEMORY) &> results/original/$*.sbk05.old_enc
	-$(RUN) $(CACHET) data/original/$*.cnf &> results/original/$*.sbk05.old_inf
	-$(ENCODE) python tools/encode.py -l data/original/$* bklm16 -m $(MAX_MEMORY) &> results/original/$*.bklm16.old_enc
	-$(ENCODE) python tools/bklm16_wrapper.py data/original/$* -m $(MAX_MEMORY) &> results/original/$*.bklm16.old_inf

data/original/%/DNE_WITH_EVIDENCE:
	$(call run_algorithms_with_evidence,dne)

data/original/%/NET_WITH_EVIDENCE:
	$(call run_algorithms_with_evidence,net)

data/original/%/TREEWIDTH:
	python tools/encode.py data/original/$* moralisation
	-$(LIMIT) && $(HTD) < data/original/$*.gr > results/original/$*.td

#===============================================================================

clean:
	for d in $(DIRECTORIES) ; do \
		rm -f data/original/$$d/*.dne.* ; \
		rm -f data/original/$$d/*.net.* ; \
		rm -f data/original/$$d/*.inst.dne ; \
		rm -f data/original/$$d/*.inst.net ; \
		rm -f data/original/$$d/*.uai.* ; \
		rm -f data/original/$$d/*.gr ; \
		rm -f data/trimmed/$$d/*.dne.* ; \
		rm -f data/trimmed/$$d/*.net.* ; \
		rm -f data/trimmed/$$d/*.inst.dne ; \
		rm -f data/trimmed/$$d/*.inst.net ; \
		rm -f data/trimmed/$$d/*.uai.* ; \
	done

# arguments: 1) CNF file, 2) answer file
define test_bklm
	ANSWER=$$($(ALGORITHM) --wf 2 --cf $(1) | awk '/s wmc/ {print $$3}') ; \
	CORRECT_ANSWER=$$(cat $(2)) ; \
	DIFFERENCE=$$(echo "$$ANSWER-$$CORRECT_ANSWER" | bc -l) ; \
	APPROXIMATELY_CORRECT=$$(echo "$${DIFFERENCE#-} < $(EPSILON)" | bc -l) ; \
	if [ "$$APPROXIMATELY_CORRECT" -eq "0" ]; then \
		echo "BKLM16 failed on $(1). The right answer is $$CORRECT_ANSWER, but BKLM16 returned $$ANSWER."; \
		exit 1; \
	fi
endef

# cd05 and cd06 are supposed to produce wrong answers
%.test: %.net %.answer %.inst %.inst.answer $(ALGORITHM) tools/encode.py
# NET
	python tools/encode.py $< cw
	$(ALGORITHM) --wf 5 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "CW failed on $@" && exit 1)
	python tools/encode.py $< d02
	$(ALGORITHM) --wf 2 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "D02 failed on $@" && exit 1)
	python tools/encode.py $< sbk05
	$(ALGORITHM) --wf 2 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "SBK05 failed on $@" && exit 1)
	python tools/encode.py $< bklm16
	$(call test_bklm,$<.cnf,$(word 2, $?))
# NET with evidence
	python tools/encode.py $< -e $(word 3, $?) cw
	$(ALGORITHM) --wf 5 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "CW failed on $@" && exit 1)
	python tools/encode.py $< -e $(word 3, $?) d02
	$(ALGORITHM) --wf 2 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "D02 failed on $@" && exit 1)
	python tools/encode.py $< -e $(word 3, $?) sbk05
	$(ALGORITHM) --wf 2 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "SBK05 failed on $@" && exit 1)
	python tools/encode.py $< -e $(word 3, $?) bklm16
	$(call test_bklm,$<.cnf,$(word 4, $?))

%.test: %.dne %.answer %.inst %.inst.answer $(ALGORITHM) tools/encode.py
# DNE
	python tools/encode.py $< cw
	$(ALGORITHM) --wf 5 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "CW failed on $@" && exit 1)
	python tools/encode.py $< d02
	$(ALGORITHM) --wf 2 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "D02 failed on $@" && exit 1)
	python tools/encode.py $< sbk05
	$(ALGORITHM) --wf 2 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "SBK05 failed on $@" && exit 1)
	python tools/encode.py $< bklm16
	$(call test_bklm,$<.cnf,$(word 2, $?))
# DNE with evidence
	python tools/encode.py $< -e $(word 3, $?) cw
	$(ALGORITHM) --wf 5 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "CW failed on $@" && exit 1)
	python tools/encode.py $< -e $(word 3, $?) d02
	$(ALGORITHM) --wf 2 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "D02 failed on $@" && exit 1)
	python tools/encode.py $< -e $(word 3, $?) sbk05
	$(ALGORITHM) --wf 2 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "SBK05 failed on $@" && exit 1)
	python tools/encode.py $< -e $(word 3, $?) bklm16
	$(call test_bklm,$<.cnf,$(word 4, $?))

test: $(addsuffix .test, $(basename $(wildcard test_data/*.inst)))
	@echo "Success, all tests passed."
