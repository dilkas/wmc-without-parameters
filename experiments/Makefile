TIMEOUT = 1000
ALGORITHM := timeout $(TIMEOUT) /usr/bin/time -v ./ADDMC/counting/addmc

CACHET_FLAG := --wf 3
MY_FLAG := --wf 4

CACHET_DATA := ./data/Grid/Cnf/
MY_DATA := ./data/Grid/Cnf2/

CACHET_OUTPUT := ./results/sang/Grid/
MY_OUTPUT := ./results/conditional/Grid/

all: $(addsuffix /MAKE_TARGET,$(wildcard $(CACHET_DATA)*/*))
all: $(addsuffix /MAKE_TARGET,$(wildcard $(MY_DATA)*/*))

clean:
	rm -f $(CACHET_OUTPUT)Ratio_50/*
	rm -f $(CACHET_OUTPUT)Ratio_75/*
	rm -f $(CACHET_OUTPUT)Ratio_90/*
	rm -f $(MY_OUTPUT)Ratio_50/*
	rm -f $(MY_OUTPUT)Ratio_75/*
	rm -f $(MY_OUTPUT)Ratio_90/*

./data/Grid/Cnf/%/MAKE_TARGET:
	-$(ALGORITHM) $(CACHET_FLAG) --cf $(CACHET_DATA)$* &> $(CACHET_OUTPUT)$*

./data/Grid/Cnf2/%/MAKE_TARGET:
	-$(ALGORITHM) $(MY_FLAG) --cf $(MY_DATA)$* &> $(MY_OUTPUT)$*
