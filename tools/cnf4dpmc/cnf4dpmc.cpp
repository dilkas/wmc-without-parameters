#include <fstream>

#include "../../deps/cxxopts.hpp"

int main(int argc, char *argv[]) {
  cxxopts::Options options("cnf4dpmc", "Modify a CNF encoding produced by Ace to optimise it for DPMC");
  options.add_options()("f,filename", "a Bayesian network", cxxopts::value<std::string>());
  auto result = options.parse(argc, argv);
  if (!result.count("filename")) {
    std::cout << options.help() << std::endl;
    exit(0);
  }
  std::string bn_filename = result["filename"].as<std::string>();
  std::string cnf_filename = bn_filename + ".cnf";
  std::string lmap_filename = bn_filename + ".lmap";

  std::ifstream lmap_file(lmap_filename);
  std::string line;
  int previous_indicator = 0;
  int num_vars = 0;
  while (std::getline(lmap_file, line)) {
    std::istringstream iss(line);
    std::string token;
    std::getline(iss, token, '$');
    if (token != "cc")
      continue;
    std::getline(iss, token, '$');
    if (token == "N") {
      std::string num_vars_string;
      std::getline(iss, num_vars_string, '$');
      num_vars = std::stoi(num_vars_string);
    }
    if (token != "I")
      continue;
    std::getline(iss, token, '$');
    int indicator = std::stoi(token);
    for (int parameter = previous_indicator + 1; parameter < indicator; parameter++) {
      std::cout << parameter << std::endl;
    }
    previous_indicator = indicator;
  }
  for (int parameter = previous_indicator + 1; parameter <= num_vars; parameter++)
    std::cout << parameter << std::endl;
}
