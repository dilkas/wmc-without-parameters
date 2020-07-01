TIMEOUT = 1000
OUTPUT_DIR := ./results/temp

all: $(addsuffix /MAKE_TARGET,$(wildcard data/Grid/*/*.dne))

# TODO: limit memory usage
data/%/MAKE_TARGET:
	python dne2cnf.py data/$* db20
	-timeout $(TIMEOUT) /usr/bin/time -v ./ADDMC/counting/addmc --wf 4 --cf data/$*.cnf &> $(OUTPUT_DIR)/$*.db20
	python dne2cnf.py data/$* d02
	-timeout $(TIMEOUT) /usr/bin/time -v ./ADDMC/counting/addmc --cf data/$*.cnf &> $(OUTPUT_DIR)/$*.d02

clean:
	rm -f data/Grid/Ratio_50/*.dne.*
	rm -f data/Grid/Ratio_75/*.dne.*
	rm -f data/Grid/Ratio_90/*.dne.*
	rm -f $(OUTPUT_DIR)/Grid/Ratio_50/*
	rm -f $(OUTPUT_DIR)/Grid/Ratio_75/*
	rm -f $(OUTPUT_DIR)/Grid/Ratio_90/*
