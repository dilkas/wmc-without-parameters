#include <fstream>

#include "../../deps/cxxopts.hpp"

enum LineType {Clause, Weight, Skip};

int rename_literal(int literal, const std::map<int, int> &decrements) {
  if (literal < 0) return -rename_literal(-literal, decrements);
  auto it = decrements.upper_bound(literal);
  //if (it == decrements.end()) return literal;
  return literal - std::prev(it)->second;
}

int main(int argc, char *argv[]) {
  cxxopts::Options options("cnf4dpmc", "Modify a CNF encoding produced by Ace to optimise it for DPMC");
  options.add_options()("f,filename", "a Bayesian network", cxxopts::value<std::string>());
  auto result = options.parse(argc, argv);
  if (!result.count("filename")) {
    std::cout << options.help() << std::endl;
    exit(0);
  }
  std::string bn_filename = result["filename"].as<std::string>();

  // Read the LMAP file, creating the 'decrements' map
  std::string lmap_filename = bn_filename + ".lmap";
  std::ifstream lmap_file(lmap_filename);
  std::string line;
  int previous_indicator = 0;
  int num_vars = 0;
  int decrement = 0;
  std::map<int,int> decrements;
  while (std::getline(lmap_file, line)) {
    std::istringstream iss(line);
    std::string token;
    std::getline(iss, token, '$');
    if (token != "cc") continue;
    std::getline(iss, token, '$');
    if (token == "N") {
      std::string num_vars_string;
      std::getline(iss, num_vars_string, '$');
      num_vars = std::stoi(num_vars_string);
    }
    if (token != "I") continue;
    std::getline(iss, token, '$');
    int indicator = std::stoi(token);
    for (int parameter = previous_indicator + 1; parameter < indicator; parameter++) {
      decrements[parameter] = ++decrement;
      std::cout << "parameter variable: " << parameter << ", its decrement: " << decrement << std::endl;
    }
    previous_indicator = indicator;
  }
  for (int parameter = previous_indicator + 1; parameter <= num_vars; parameter++) {
    decrements[parameter] = ++decrement;
    std::cout << "parameter variable: " << parameter << ", its decrement: " << decrement << std::endl;
  }

  // Translate the CNF
  std::string cnf_filename = bn_filename + ".cnf";
  std::ifstream cnf_file(cnf_filename);
  while (std::getline(cnf_file, line)) {
    std::istringstream iss(line);
    std::string token;
    iss >> token;
    if (token == "c") {
      // TODO: Read the weights of parameter variables into a map. Otherwise ignore the line.
      iss >> token;
      std::ostringstream oss;
      for (int i = 1; i <= 2 * num_vars; i++) {
        iss >> token;
        auto it = decrements.find((i+1)/2);
        if (it == decrements.end()) {
          oss << " " << token;
        }
      }
    } else if (token[0] != 'p') {
      std::vector<int> literals;
      LineType line_type = Clause;
      while (token != "0") {
        int literal = std::stoi(token);
        if (literal < 0 && decrements.find(-literal) != decrements.end()) {
          line_type = Skip;
          break;
        }
        if (literal > 0 && decrements.find(literal) != decrements.end()) {
          line_type = Weight;
        } else {
          literals.push_back(rename_literal(literal, decrements));
        }
        iss >> token;
      }
      if (line_type == Clause) {
        for (int literal : literals)
          std::cout << literal << " ";
        std::cout << "0" << std::endl;
      } else if (line_type == Weight) {
        std::cout << "w";
        for (int literal : literals)
          std::cout << " " << -literal;
        std::cout << std::endl;
      }
    }
  }
}
