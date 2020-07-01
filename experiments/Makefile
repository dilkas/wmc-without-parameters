TIMEOUT = 1000
OUTPUT_DIR := ./results/temp

all: $(addsuffix /MAKE_TARGET,$(wildcard data/Grid/*/*.dne))

./data/%/MAKE_TARGET:
	./ace/compile -encodeOnly -noEclause -d02 data/$*
	-timeout $(TIMEOUT) /usr/bin/time -v ./ADDMC/counting/addmc --wf 3 --cf data/$*.cnf &> $(OUTPUT_DIR)/$*

#clean:
#	rm -f $(CACHET_OUTPUT)Ratio_50/*
#	rm -f $(CACHET_OUTPUT)Ratio_75/*
#	rm -f $(CACHET_OUTPUT)Ratio_90/*
#	rm -f $(MY_OUTPUT)Ratio_50/*
#	rm -f $(MY_OUTPUT)Ratio_75/*
#	rm -f $(MY_OUTPUT)Ratio_90/*

#./data/Grid/Cnf2/%/MAKE_TARGET:
#	-$(ALGORITHM) $(MY_FLAG) --cf $(MY_DATA)$* &> $(MY_OUTPUT)$*
