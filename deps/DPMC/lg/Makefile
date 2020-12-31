appname := lg

CXX := g++
CXXFLAGS := -g -std=c++17 -O3 -DNDEBUG -I ./src -pedantic
LDLIBS := /usr/lib/libboost_system.a -pthread

srcfiles := $(shell find . -name "*.cc" -not -path "./solvers/*")
headers := $(shell find . -name "*.h" -not -path "./solvers/*")
objects  := $(patsubst ./%.cpp, ./%.o, $(patsubst ./%.cc, ./%.o, $(srcfiles)))

all: build/$(appname)

build/$(appname): $(objects)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o build/$(appname) $(objects) $(LDLIBS)

build/.depend: $(srcfiles)
	mkdir -p build
	$(CXX) $(CXXFLAGS) -MM $^>>./build/.depend;

clean:
	rm -f $(objects)
	rm -rf ./build
	rm -f $(appname).sif

dist-clean: clean
	rm -f *~ ./build/.depend

$(appname).sif: Singularity $(srcfiles) $(headers)
	rm -f $(appname).sif
	singularity build $(appname).sif Singularity

ifneq ($(MAKECMDGOALS), clean)
ifneq ($(MAKECMDGOALS), $(appname).sif)
include build/.depend
endif
endif
