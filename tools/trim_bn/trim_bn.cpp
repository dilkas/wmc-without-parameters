#include "../../deps/cxxopts.hpp"

int main(int argc, char *argv[]) {
  cxxopts::Options options("./trim_bn", "Trim a Bayesian network by removing variables irrelevant to the query");
  options.add_options()
    ("n,network", "a Bayesian network (in one of DNE/NET/Hugin formats)", cxxopts::value<std::string>())
    ("e,evidence", "(optional) evidence file (in the INST format)", cxxopts::value<std::string>())
    ;
  auto result = options.parse(argc, argv);
  if (!result.count("network")) {
    std::cout << options.help() << std::endl;
    return 0;
  }
}
