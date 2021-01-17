#include <cassert>
#include <fstream>

#include "../../deps/cxxopts.hpp"

enum LineType {Clause, Weight, Skip};

int rename_literal(int literal, const std::map<int, int> &decrements) {
  if (literal < 0) return -rename_literal(-literal, decrements);
  if (decrements.empty() || literal < decrements.begin()->first) return literal;
  auto it = decrements.upper_bound(literal);
  int new_literal = literal - std::prev(it)->second;
  assert(new_literal > 0);
  return new_literal;
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
    if (indicator <= 0) continue;
    for (int parameter = previous_indicator + 1; parameter < indicator; parameter++)
      decrements[parameter] = ++decrement;
    previous_indicator = indicator;
  }
  for (int parameter = previous_indicator + 1; parameter <= num_vars; parameter++)
    decrements[parameter] = ++decrement;

  // Read the CNF file, translating variable names, removing some clauses and
  // turning some other clauses into weight lines.
  std::string cnf_filename = bn_filename + ".cnf";
  std::ifstream cnf_file(cnf_filename);
  std::map<int,std::string> weights;
  std::vector<std::vector<int>> new_literals;
  std::vector<int> new_parameters;
  int num_clauses = 0;
  while (std::getline(cnf_file, line)) {
    std::istringstream iss(line);
    std::string token;
    iss >> token;
    if (token == "c") {
      iss >> token;
      for (int i = 1; i <= 2 * num_vars; i++) {
        iss >> token;
        int variable = (i+1)/2;
        if (i % 2 == 1 && decrements.find(variable) != decrements.end())
          weights[variable] = token;
      }
    } else if (token[0] != 'p') {
      std::vector<int> literals;
      int parameter_variable = 0;
      LineType line_type = Clause;
      while (token != "0") {
        int literal = std::stoi(token);
        if (literal < 0 && decrements.find(-literal) != decrements.end()) {
          line_type = Skip;
          break;
        }
        if (literal > 0 && decrements.find(literal) != decrements.end()) {
          line_type = Weight;
          parameter_variable = literal;
        } else {
          literals.push_back(rename_literal(literal, decrements));
        }
        iss >> token;
      }
      if (line_type != Skip) {
        new_literals.push_back(literals);
        new_parameters.push_back(parameter_variable);
        if (line_type == Clause) num_clauses++;
      }
    }
  }

  // Weight lines with weight = 1 can be removed
  for (size_t i = 0; i < new_literals.size(); i++)
    if (new_parameters[i] != 0 && !new_literals[i].empty() && std::stod(weights[new_parameters[i]]) == 1) {
      new_parameters.erase(new_parameters.begin() + i);
      new_literals.erase(new_literals.begin() + i);
      i--;
    }

  // Compile and output the new encoding
  std::ofstream output(cnf_filename);
  output << "p cnf " << num_vars - decrements.size() << " " << num_clauses << std::endl;
  double premultiplication_constant = 1;
  for (size_t i = 0; i < new_literals.size(); i++) {
    if (new_parameters[i] == 0) {
      for (int literal : new_literals[i]) output << literal << " ";
      output << "0" << std::endl;
    } else if (new_literals[i].empty()) {
      premultiplication_constant *= std::stod(weights[new_parameters[i]]);
    } else {
      output << "w";
      for (int literal : new_literals[i]) output << " " << -literal;
      output << " " << weights[new_parameters[i]] << std::endl;
    }
  }
  if (premultiplication_constant != 1) output << "w 0 " << premultiplication_constant << std::endl;
}
