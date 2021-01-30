TIMEOUT := 10
MAX_MEMORY = 32 # in GB
MAX_MEMORY_KB = 31876710 # 95% of MAX_MEMORY
EPSILON := 0.000001

EVALUATE := deps/ace/evaluate
CACHET := deps/cachet/cachet
HTD := deps/DPMC/lg/solvers/htd-master/bin/htd_main --opt width --iterations 0 --strategy challenge --print-progress --preprocessing full --output width
LG := deps/DPMC/lg/build/lg \"deps/DPMC/lg/solvers/htd-master/bin/htd_main --opt width --iterations 1 --strategy challenge --print-progress --preprocessing full\"
DPMC := deps/DPMC/DMC/dmc --jf=- --pf=1e-3 --jw=$(TIMEOUT)

LIMIT := ulimit -t $(TIMEOUT) -Sv $(MAX_MEMORY_KB)
RUN := $(LIMIT) && /usr/bin/time -v
ENCODE := ulimit -t $(TIMEOUT) && /usr/bin/time -v

DIRECTORIES := Grid/Ratio_50 Grid/Ratio_75 Grid/Ratio_90 DQMR/qmr-100 DQMR/qmr-50 DQMR/qmr-60 DQMR/qmr-70 Plan_Recognition/without_evidence Plan_Recognition/with_evidence 2004-pgm 2005-ijcai 2006-ijar ../test_data

#all: $(addsuffix /NET_WITH_EVIDENCE,$(wildcard data/2005-ijcai/*.inst))
#all: $(addsuffix /NET_WITH_EVIDENCE,$(wildcard data/2006-ijar/*.inst))
#all: $(addsuffix /NET_WITH_EVIDENCE,$(wildcard data/2004-pgm/*.inst))
#all: $(addsuffix /WITHOUT_EVIDENCE,$(wildcard data/Plan_Recognition/without_evidence/*.dne))
#all: $(addsuffix /DNE_WITH_EVIDENCE,$(wildcard data/Plan_Recognition/with_evidence/*.inst))
all: $(addsuffix /WITHOUT_EVIDENCE,$(wildcard data/DQMR/qmr-100/*.dne))
#all: $(addsuffix /DNE_WITH_EVIDENCE,$(wildcard data/DQMR/qmr-50/*.inst))
#all: $(addsuffix /DNE_WITH_EVIDENCE,$(wildcard data/DQMR/qmr-60/*.inst))
#all: $(addsuffix /DNE_WITH_EVIDENCE,$(wildcard data/DQMR/qmr-70/*.inst))
#all: $(addsuffix /WITHOUT_EVIDENCE,$(wildcard data/Grid/*/*.dne))

#all: $(addsuffix /TREEWIDTH,$(wildcard data/2005-ijcai/*.net))
#all: $(addsuffix /TREEWIDTH,$(wildcard data/2006-ijar/*.net))
#all: $(addsuffix /TREEWIDTH,$(wildcard data/2004-pgm/*.net))
#all: $(addsuffix /TREEWIDTH,$(wildcard data/Plan_Recognition/without_evidence/*.dne))
#all: $(addsuffix /TREEWIDTH,$(wildcard data/Plan_Recognition/with_evidence/*.dne))
#all: $(addsuffix /TREEWIDTH,$(wildcard data/DQMR/qmr-100/*.dne))
#all: $(addsuffix /TREEWIDTH,$(wildcard data/DQMR/qmr-50/*.dne))
#all: $(addsuffix /TREEWIDTH,$(wildcard data/DQMR/qmr-60/*.dne))
#all: $(addsuffix /TREEWIDTH,$(wildcard data/DQMR/qmr-70/*.dne))
#all: $(addsuffix /TREEWIDTH,$(wildcard data/Grid/*/*.dne))

#===============================================================================

# Arguments: 1) CNF file, 2) weight format number, 3) (most of the) results filename
define run_dpmc
	cnf="data/$(1)" && $(LIMIT) && /usr/bin/time -v -f "%es" bash -c "$(LG) < $$cnf | $(DPMC) --cf=$$cnf --wf $(2)" &> results/$(3).new_inf
endef

# Same but without recording output to file
define run_dpmc2
	cnf="$(1)" && bash -c "$(LG) < $$cnf | $(DPMC) --cf=$$cnf --wf $(2)"
endef


# The argument is the file format (dne or net)
define run_algorithms_with_evidence
	-cp data/$(shell echo $* | sed "s/-[a-z0-9]\+\.inst/\.$(1)/g") data/$*.$(1)
	-cp data/$(basename $*).$(1) data/$*.$(1)
	-$(ENCODE) python tools/encode.py d02 basic data/$*.$(1) -e data/$* -m $(MAX_MEMORY) &> results/$*.d02.new_enc
	-$(call run_dpmc,$*.$(1).cnf,2,$*.d02)
	-$(ENCODE) python tools/encode.py sbk05 basic data/$*.$(1) -e data/$* -m $(MAX_MEMORY) &> results/$*.sbk05.new_enc
	-$(call run_dpmc,$*.$(1).cnf,2,$*.sbk05)
	-$(ENCODE) python tools/encode.py bklm16 basic data/$*.$(1) -e data/$* -m $(MAX_MEMORY) &> results/$*.bklm16.new_enc
	-$(call run_dpmc,$*.$(1).cnf,2,$*.bklm16)
	-$(ENCODE) python tools/encode.py cd05 legacy data/$*.$(1) -e data/$* -m $(MAX_MEMORY) &> results/$*.cd05.old_enc
	-$(RUN) $(EVALUATE) data/$*.$(1) &> results/$*.cd05.old_inf
	-$(ENCODE) python tools/encode.py cd06 legacy data/$*.$(1) -e data/$* -m $(MAX_MEMORY) &> results/$*.cd06.old_enc
	-$(RUN) $(EVALUATE) data/$*.$(1) &> results/$*.cd06.old_inf
	-$(ENCODE) python tools/encode.py d02 legacy data/$*.$(1) -e data/$* -m $(MAX_MEMORY) &> results/$*.d02.old_enc
	-$(RUN) $(EVALUATE) data/$*.$(1) &> results/$*.d02.old_inf
	-$(ENCODE) python tools/encode.py sbk05 legacy data/$*.$(1) -e data/$* -m $(MAX_MEMORY) &> results/$*.sbk05.old_enc
	-$(RUN) $(CACHET) data/$*.$(1).cnf &> results/$*.sbk05.old_inf
	-$(ENCODE) python tools/encode.py bklm16 legacy data/$*.$(1) -e data/$* -m $(MAX_MEMORY) &> results/$*.bklm16.old_enc
	-$(ENCODE) python tools/bklm16_wrapper.py data/$*.$(1) -m $(MAX_MEMORY) &> results/$*.bklm16.old_inf
	-$(ENCODE) python tools/encode.py d02 optimised data/$*.$(1) -e data/$* -m $(MAX_MEMORY) &> results/$*.d02pp.new_enc
	-$(call run_dpmc,$*.$(1).cnf,5,$*.d02pp)
	-$(ENCODE) python tools/encode.py cd05 optimised data/$*.$(1) -e data/$* -m $(MAX_MEMORY) &> results/$*.cd05pp.new_enc
	-$(call run_dpmc,$*.$(1).cnf,5,$*.cd05pp)
	-$(ENCODE) python tools/encode.py cd06 optimised data/$*.$(1) -e data/$* -m $(MAX_MEMORY) &> results/$*.cd06pp.new_enc
	-$(call run_dpmc,$*.$(1).cnf,5,$*.cd06pp)
	-$(ENCODE) python tools/encode.py bklm16 optimised data/$*.$(1) -e data/$* -m $(MAX_MEMORY) &> results/$*.bklm16pp.new_enc
	-$(call run_dpmc,$*.$(1).cnf,5,$*.bklm16pp)
	-$(ENCODE) python tools/encode.py cd05 basic data/$*.$(1) -e data/$* -m $(MAX_MEMORY) &> results/$*.cd05.new_enc
	-$(ENCODE) python tools/encode.py cd06 basic data/$*.$(1) -e data/$* -m $(MAX_MEMORY) &> results/$*.cd06.new_enc
endef

data/%/WITHOUT_EVIDENCE:
	-$(ENCODE) python tools/encode.py d02 basic data/$* -m $(MAX_MEMORY) &> results/$*.d02.new_enc
	-$(call run_dpmc,$*.cnf,2,$*.d02)
	-$(ENCODE) python tools/encode.py sbk05 basic data/$* -m $(MAX_MEMORY) &> results/$*.sbk05.new_enc
	-$(call run_dpmc,$*.cnf,2,$*.sbk05)
	-$(ENCODE) python tools/encode.py bklm16 basic data/$* -m $(MAX_MEMORY) &> results/$*.bklm16.new_enc
	-$(call run_dpmc,$*.cnf,2,$*.bklm16)
	-$(ENCODE) python tools/encode.py cd05 legacy data/$* -m $(MAX_MEMORY) &> results/$*.cd05.old_enc
	-$(RUN) $(EVALUATE) data/$* &> results/$*.cd05.old_inf
	-$(ENCODE) python tools/encode.py cd06 legacy data/$* -m $(MAX_MEMORY) &> results/$*.cd06.old_enc
	-$(RUN) $(EVALUATE) data/$* &> results/$*.cd06.old_inf
	-$(ENCODE) python tools/encode.py d02 legacy data/$* -m $(MAX_MEMORY) &> results/$*.d02.old_enc
	-$(RUN) $(EVALUATE) data/$* &> results/$*.d02.old_inf
	-$(ENCODE) python tools/encode.py sbk05 legacy data/$* -m $(MAX_MEMORY) &> results/$*.sbk05.old_enc
	-$(RUN) $(CACHET) data/$*.cnf &> results/$*.sbk05.old_inf
	-$(ENCODE) python tools/encode.py bklm16 legacy data/$* -m $(MAX_MEMORY) &> results/$*.bklm16.old_enc
	-$(ENCODE) python tools/bklm16_wrapper.py data/$* -m $(MAX_MEMORY) &> results/$*.bklm16.old_inf
	-$(ENCODE) python tools/encode.py d02 optimised data/$* -m $(MAX_MEMORY) &> results/$*.d02pp.new_enc
	-$(call run_dpmc,$*.cnf,5,$*.d02pp)
	-$(ENCODE) python tools/encode.py cd05 optimised data/$* -m $(MAX_MEMORY) &> results/$*.cd05pp.new_enc
	-$(call run_dpmc,$*.cnf,5,$*.cd05pp)
	-$(ENCODE) python tools/encode.py cd06 optimised data/$* -m $(MAX_MEMORY) &> results/$*.cd06pp.new_enc
	-$(call run_dpmc,$*.cnf,5,$*.cd06pp)
	-$(ENCODE) python tools/encode.py bklm16 optimised data/$* -m $(MAX_MEMORY) &> results/$*.bklm16pp.new_enc
	-$(call run_dpmc,$*.cnf,5,$*.bklm16pp)
	-$(ENCODE) python tools/encode.py cd05 basic data/$* -m $(MAX_MEMORY) &> results/$*.cd05.new_enc
	-$(ENCODE) python tools/encode.py cd06 basic data/$* -m $(MAX_MEMORY) &> results/$*.cd06.new_enc

data/%/DNE_WITH_EVIDENCE:
	$(call run_algorithms_with_evidence,dne)

data/%/NET_WITH_EVIDENCE:
	$(call run_algorithms_with_evidence,net)

data/%/TREEWIDTH:
	python tools/encode.py stats basic data/$*
	python tools/encode.py moralisation basic data/$*
	-$(LIMIT) && $(HTD) < data/$*.gr > results/$*.td

#===============================================================================

clean:
	-rm *.dot
	-rm *.png
	for d in $(DIRECTORIES) ; do \
		rm -f data/$$d/*.dne.* ; \
		rm -f data/$$d/*.net.* ; \
		rm -f data/$$d/*.inst.dne ; \
		rm -f data/$$d/*.inst.net ; \
		rm -f data/$$d/*.uai.* ; \
		rm -f data/$$d/*.gr ; \
	done

# arguments: 1) CNF file, 2) answer file, 3) weight format
define test_bklm
	ANSWER=$$($(call run_dpmc2,$(1),$(3)) | awk '/s wmc/ {print $$3}') ; \
	CORRECT_ANSWER=$$(cat $(2)) ; \
	DIFFERENCE=$$(echo "$$ANSWER-$$CORRECT_ANSWER" | bc -l) ; \
	APPROXIMATELY_CORRECT=$$(echo "$${DIFFERENCE#-} < $(EPSILON)" | bc -l) ; \
	if [ "$$APPROXIMATELY_CORRECT" -eq "0" ]; then \
		echo "BKLM16 failed on $(1). The right answer is $$CORRECT_ANSWER, but BKLM16 returned $$ANSWER."; \
		exit 1; \
	fi
endef

# cd05 and cd06 are supposed to produce wrong answers
%.test: %.net %.answer %.inst %.inst.answer tools/encode.py
# basic NET
	python tools/encode.py d02 basic $<
	$(call run_dpmc2,$<.cnf,2) | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "basic D02 failed on $@" && exit 1)
	python tools/encode.py sbk05 basic $<
	$(call run_dpmc2,$<.cnf,2) | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "basic SBK05 failed on $@" && exit 1)
	python tools/encode.py bklm16 basic $<
	$(call test_bklm,$<.cnf,$(word 2, $?),2)
# basic NET with evidence
	python tools/encode.py d02 basic $< -e $(word 3, $?)
	$(call run_dpmc2,$<.cnf,2) | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "basic D02 failed on $@" && exit 1)
	python tools/encode.py sbk05 basic $< -e $(word 3, $?)
	$(call run_dpmc2,$<.cnf,2) | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "basic SBK05 failed on $@" && exit 1)
	python tools/encode.py bklm16 basic $< -e $(word 3, $?)
	$(call test_bklm,$<.cnf,$(word 4, $?),2)
# optimised NET
	python tools/encode.py d02 optimised $<
	$(call run_dpmc2,$<.cnf,5) | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "optimised D02 failed on $@" && exit 1)
	python tools/encode.py cd05 optimised $<
	$(call run_dpmc2,$<.cnf,5) | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "optimised CD05 failed on $@" && exit 1)
	python tools/encode.py cd06 optimised $<
	$(call run_dpmc2,$<.cnf,5) | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "optimised CD06 failed on $@" && exit 1)
	python tools/encode.py bklm16 optimised $<
	$(call run_dpmc2,$<.cnf,5) | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "optimised BKLM16 failed on $@" && exit 1)
# optimised NET with evidence
	python tools/encode.py d02 optimised $< -e $(word 3, $?)
	$(call run_dpmc2,$<.cnf,5) | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "optimised D02 failed on $@" && exit 1)
	python tools/encode.py cd05 optimised $< -e $(word 3, $?)
	$(call run_dpmc2,$<.cnf,5) | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "optimised CD05 failed on $@" && exit 1)
	python tools/encode.py cd06 optimised $< -e $(word 3, $?)
	$(call run_dpmc2,$<.cnf,5) | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "optimised CD06 failed on $@" && exit 1)
	python tools/encode.py bklm16 optimised $< -e $(word 3, $?)
	$(call run_dpmc2,$<.cnf,5) | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "optimised BKLM16 failed on $@" && exit 1)

%.test: %.dne %.answer %.inst %.inst.answer tools/encode.py
# basic DNE
	python tools/encode.py d02 basic $<
	$(call run_dpmc2,$<.cnf,2) | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "basic D02 failed on $@" && exit 1)
	python tools/encode.py sbk05 basic $<
	$(call run_dpmc2,$<.cnf,2) | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "basic SBK05 failed on $@" && exit 1)
	python tools/encode.py bklm16 basic $<
	$(call test_bklm,$<.cnf,$(word 2, $?),2)
# basic DNE with evidence
	python tools/encode.py d02 basic $< -e $(word 3, $?)
	$(call run_dpmc2,$<.cnf,2) | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "basic D02 failed on $@" && exit 1)
	python tools/encode.py sbk05 basic $< -e $(word 3, $?)
	$(call run_dpmc2,$<.cnf,2) | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "basic SBK05 failed on $@" && exit 1)
	python tools/encode.py bklm16 basic $< -e $(word 3, $?)
	$(call test_bklm,$<.cnf,$(word 4, $?),2)
# optimised DNE
	python tools/encode.py d02 optimised $<
	$(call run_dpmc2,$<.cnf,5) | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "optimised D02 failed on $@" && exit 1)
	python tools/encode.py cd05 optimised $<
	$(call run_dpmc2,$<.cnf,5) | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "optimised CD05 failed on $@" && exit 1)
	python tools/encode.py cd06 optimised $<
	$(call run_dpmc2,$<.cnf,5) | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "optimised CD06 failed on $@" && exit 1)
	python tools/encode.py bklm16 optimised $<
	$(call run_dpmc2,$<.cnf,5) | awk '/s wmc/ {print $$3}' | diff -q $(word 2, $?) - >/dev/null || (echo "optimised BKLM16 failed on $@" && exit 1)
# optimised DNE with evidence
	python tools/encode.py d02 optimised $< -e $(word 3, $?)
	$(call run_dpmc2,$<.cnf,5) | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "optimised D02 failed on $@" && exit 1)
	python tools/encode.py cd05 optimised $< -e $(word 3, $?)
	$(call run_dpmc2,$<.cnf,5) | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "optimised CD05 failed on $@" && exit 1)
	python tools/encode.py cd06 optimised $< -e $(word 3, $?)
	$(call run_dpmc2,$<.cnf,5) | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "optimised CD06 failed on $@" && exit 1)
	python tools/encode.py bklm16 optimised $< -e $(word 3, $?)
	$(call run_dpmc2,$<.cnf,5) | awk '/s wmc/ {print $$3}' | diff -q $(word 4, $?) - >/dev/null || (echo "optimised BKLM16 failed on $@" && exit 1)

test: $(addsuffix .test, $(basename $(wildcard test_data/*.inst)))
	@echo "Success, all tests passed."

compile:
	@for f in $(shell ls ./*.dot); do dot -Tpng $${f} > $${f}.png; done
