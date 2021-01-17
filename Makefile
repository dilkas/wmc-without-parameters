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
#all: $(addsuffix /TREEWIDTH,$(wildcard data/original/DQMR/qmr-50/*.dne))
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
	-$(ENCODE) python tools/encode.py cd05 basic data/original/$*.$(1) -e data/original/$* -m $(MAX_MEMORY) &> results/original/$*.cd05.new_enc
	-$(call run_dpmc,original/$*.$(1).cnf,2,original/$*.cd05)
	-$(ENCODE) python tools/encode.py cd06 basic data/original/$*.$(1) -e data/original/$* -m $(MAX_MEMORY) &> results/original/$*.cd06.new_enc
	-$(call run_dpmc,original/$*.$(1).cnf,2,original/$*.cd06)
	-$(ENCODE) python tools/encode.py d02 basic data/original/$*.$(1) -e data/original/$* -m $(MAX_MEMORY) &> results/original/$*.d02.new_enc
	-$(call run_dpmc,original/$*.$(1).cnf,2,original/$*.d02)
	-$(ENCODE) python tools/encode.py sbk05 basic data/original/$*.$(1) -e data/original/$* -m $(MAX_MEMORY) &> results/original/$*.sbk05.new_enc
	-$(call run_dpmc,original/$*.$(1).cnf,2,original/$*.sbk05)
	-$(ENCODE) python tools/encode.py bklm16 basic data/original/$*.$(1) -e data/original/$* -m $(MAX_MEMORY) &> results/original/$*.bklm16.new_enc
	-$(call run_dpmc,original/$*.$(1).cnf,2,original/$*.bklm16)
	-$(ENCODE) python tools/encode.py cd05 basic -l data/original/$*.$(1) -e data/original/$* -m $(MAX_MEMORY) &> results/original/$*.cd05.old_enc
	-$(RUN) $(EVALUATE) data/original/$*.$(1) &> results/original/$*.cd05.old_inf
	-$(ENCODE) python tools/encode.py cd06 basic -l data/original/$*.$(1) -e data/original/$* -m $(MAX_MEMORY) &> results/original/$*.cd06.old_enc
	-$(RUN) $(EVALUATE) data/original/$*.$(1) &> results/original/$*.cd06.old_inf
	-$(ENCODE) python tools/encode.py d02 basic -l data/original/$*.$(1) -e data/original/$* -m $(MAX_MEMORY) &> results/original/$*.d02.old_enc
	-$(RUN) $(EVALUATE) data/original/$*.$(1) &> results/original/$*.d02.old_inf
	-$(ENCODE) python tools/encode.py sbk05 basic -l data/original/$*.$(1) -e data/original/$* -m $(MAX_MEMORY) &> results/original/$*.sbk05.old_enc
	-$(RUN) $(CACHET) data/original/$*.$(1).cnf &> results/original/$*.sbk05.old_inf
	-$(ENCODE) python tools/encode.py bklm16 basic -l data/original/$*.$(1) -e data/original/$* -m $(MAX_MEMORY) &> results/original/$*.bklm16.old_enc
	-$(ENCODE) python tools/bklm16_wrapper.py data/original/$*.$(1) -m $(MAX_MEMORY) &> results/original/$*.bklm16.old_inf
endef

data/original/%/WITHOUT_EVIDENCE:
	-$(ENCODE) python tools/encode.py cd05 basic data/original/$* -m $(MAX_MEMORY) &> results/original/$*.cd05.new_enc
	-$(call run_dpmc,original/$*.cnf,2,original/$*.cd05)
	-$(ENCODE) python tools/encode.py cd06 basic data/original/$* -m $(MAX_MEMORY) &> results/original/$*.cd06.new_enc
	-$(call run_dpmc,original/$*.cnf,2,original/$*.cd06)
	-$(ENCODE) python tools/encode.py d02 basic data/original/$* -m $(MAX_MEMORY) &> results/original/$*.d02.new_enc
	-$(call run_dpmc,original/$*.cnf,2,original/$*.d02)
	-$(ENCODE) python tools/encode.py sbk05 basic data/original/$* -m $(MAX_MEMORY) &> results/original/$*.sbk05.new_enc
	-$(call run_dpmc,original/$*.cnf,2,original/$*.sbk05)
	-$(ENCODE) python tools/encode.py bklm16 basic data/original/$* -m $(MAX_MEMORY) &> results/original/$*.bklm16.new_enc
	-$(call run_dpmc,original/$*.cnf,2,original/$*.bklm16)
	-$(ENCODE) python tools/encode.py cd05 basic -l data/original/$* -m $(MAX_MEMORY) &> results/original/$*.cd05.old_enc
	-$(RUN) $(EVALUATE) data/original/$* &> results/original/$*.cd05.old_inf
	-$(ENCODE) python tools/encode.py cd06 basic -l data/original/$* -m $(MAX_MEMORY) &> results/original/$*.cd06.old_enc
	-$(RUN) $(EVALUATE) data/original/$* &> results/original/$*.cd06.old_inf
	-$(ENCODE) python tools/encode.py d02 basic -l data/original/$* -m $(MAX_MEMORY) &> results/original/$*.d02.old_enc
	-$(RUN) $(EVALUATE) data/original/$* &> results/original/$*.d02.old_inf
	-$(ENCODE) python tools/encode.py sbk05 basic -l data/original/$* -m $(MAX_MEMORY) &> results/original/$*.sbk05.old_enc
	-$(RUN) $(CACHET) data/original/$*.cnf &> results/original/$*.sbk05.old_inf
	-$(ENCODE) python tools/encode.py bklm16 basic -l data/original/$* -m $(MAX_MEMORY) &> results/original/$*.bklm16.old_enc
	-$(ENCODE) python tools/bklm16_wrapper.py data/original/$* -m $(MAX_MEMORY) &> results/original/$*.bklm16.old_inf

data/original/%/DNE_WITH_EVIDENCE:
	$(call run_algorithms_with_evidence,dne)

data/original/%/NET_WITH_EVIDENCE:
	$(call run_algorithms_with_evidence,net)

data/original/%/TREEWIDTH:
	python tools/encode.py stats basic data/original/$*
	python tools/encode.py moralisation basic data/original/$*
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

# arguments: 1) CNF file, 2) answer file, 3) weight format
define test_bklm
	ANSWER=$$($(ALGORITHM) --wf $(3) --cf $(1) | awk '/s wmc/ {print $$3}') ; \
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
# basic NET
	python tools/encode.py d02 basic $<
	$(ALGORITHM) --wf 2 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "basic D02 failed on $@" && exit 1)
	python tools/encode.py sbk05 basic $<
	$(ALGORITHM) --wf 2 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "basic SBK05 failed on $@" && exit 1)
	python tools/encode.py bklm16 basic $<
	$(call test_bklm,$<.cnf,$(word 2, $?),2)
# basic NET with evidence
	python tools/encode.py d02 basic $< -e $(word 3, $?)
	$(ALGORITHM) --wf 2 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "basic D02 failed on $@" && exit 1)
	python tools/encode.py sbk05 basic $< -e $(word 3, $?)
	$(ALGORITHM) --wf 2 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "basic SBK05 failed on $@" && exit 1)
	python tools/encode.py bklm16 basic $< -e $(word 3, $?)
	$(call test_bklm,$<.cnf,$(word 4, $?),2)
# optimised NET
	python tools/encode.py d02 optimised $<
	$(ALGORITHM) --wf 5 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "optimised D02 failed on $@" && exit 1)
	python tools/encode.py cd05 optimised $<
	$(ALGORITHM) --wf 5 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "optimised CD05 failed on $@" && exit 1)
	python tools/encode.py cd06 optimised $<
	$(ALGORITHM) --wf 5 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "optimised CD06 failed on $@" && exit 1)
# optimised NET with evidence
	python tools/encode.py d02 optimised $< -e $(word 3, $?)
	$(ALGORITHM) --wf 5 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "optimised D02 failed on $@" && exit 1)
	python tools/encode.py cd05 optimised $< -e $(word 3, $?)
	$(ALGORITHM) --wf 5 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "optimised CD05 failed on $@" && exit 1)
	python tools/encode.py cd06 optimised $< -e $(word 3, $?)
	$(ALGORITHM) --wf 5 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "optimised CD06 failed on $@" && exit 1)

%.test: %.dne %.answer %.inst %.inst.answer $(ALGORITHM) tools/encode.py
# basic DNE
	python tools/encode.py d02 basic $<
	$(ALGORITHM) --wf 2 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "basic D02 failed on $@" && exit 1)
	python tools/encode.py sbk05 basic $<
	$(ALGORITHM) --wf 2 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "basic SBK05 failed on $@" && exit 1)
	python tools/encode.py bklm16 basic $<
	$(call test_bklm,$<.cnf,$(word 2, $?),2)
# basic DNE with evidence
	python tools/encode.py d02 basic $< -e $(word 3, $?)
	$(ALGORITHM) --wf 2 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "basic D02 failed on $@" && exit 1)
	python tools/encode.py sbk05 basic $< -e $(word 3, $?)
	$(ALGORITHM) --wf 2 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "basic SBK05 failed on $@" && exit 1)
	python tools/encode.py bklm16 basic $< -e $(word 3, $?)
	$(call test_bklm,$<.cnf,$(word 4, $?),2)
# optimised DNE
	python tools/encode.py d02 optimised $<
	$(ALGORITHM) --wf 5 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "optimised D02 failed on $@" && exit 1)
	python tools/encode.py cd05 optimised $<
	$(ALGORITHM) --wf 5 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "optimised CD05 failed on $@" && exit 1)
	python tools/encode.py cd06 optimised $<
	$(ALGORITHM) --wf 5 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "optimised CD06 failed on $@" && exit 1)
# optimised DNE with evidence
	python tools/encode.py d02 optimised $< -e $(word 3, $?)
	$(ALGORITHM) --wf 5 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "optimised D02 failed on $@" && exit 1)
	python tools/encode.py cd05 optimised $< -e $(word 3, $?)
	$(ALGORITHM) --wf 5 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "optimised CD05 failed on $@" && exit 1)
	python tools/encode.py cd06 optimised $< -e $(word 3, $?)
	$(ALGORITHM) --wf 5 --cf $<.cnf | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "optimised CD06 failed on $@" && exit 1)

test: $(addsuffix .test, $(basename $(wildcard test_data/*.inst)))
	@echo "Success, all tests passed."
