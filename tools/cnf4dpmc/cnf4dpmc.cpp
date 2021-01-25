#include <cassert>
#include <fstream>

#include "../../deps/cxxopts.hpp"

enum LineType {Clause, Weight, Skip};

int RenameLiteral(int literal, const std::map<int, int> &decrements) {
  if (literal < 0) {
    return -RenameLiteral(-literal, decrements);
  }
  if (decrements.empty() || literal < decrements.begin()->first) {
    return literal;
  }
  auto it = decrements.upper_bound(literal);
  int new_literal = literal - std::prev(it)->second;
  assert(new_literal > 0);
  return new_literal;
}

void AddToDecrements(int literal, std::map<int, int> *decrements) {
  auto it = decrements->upper_bound(literal);
  int decrement = (it != decrements->begin()) ? std::prev(it)->second + 1 : 1;
  for (; it != decrements->end(); it++) {
    (*decrements)[it->first] = it->second + 1;
  }
  (*decrements)[literal] = decrement;
}

void Rename(int previous, int next, std::vector<std::vector<int>> *clauses) {
  for (auto & clause : *clauses) {
    for (auto & literal : clause) {
      if (literal == previous) {
        literal = next;
      } else if (literal == -previous) {
        literal = -next;
      }
    }
  }
}

// Read the LMAP file, creating a map of decrements
int CreateDecrements(std::string bn_filename, std::map<int, int> *decrements) {
  std::string lmap_filename = bn_filename + ".lmap";
  std::ifstream lmap_file(lmap_filename);
  std::string line;
  int previous_indicator = 0;
  int num_vars = 0;
  int decrement = 0;
  while (std::getline(lmap_file, line)) {
    std::istringstream iss(line);
    std::string token;
    std::getline(iss, token, '$');
    if (token != "cc") {
      continue;
    }
    std::getline(iss, token, '$');
    if (token == "N") {
      std::string num_vars_string;
      std::getline(iss, num_vars_string, '$');
      num_vars = std::stoi(num_vars_string);
    }
    if (token != "I") {
      continue;
    }
    std::getline(iss, token, '$');
    int indicator = std::stoi(token);
    if (indicator <= 0) {
      continue;
    }
    for (int parameter = previous_indicator + 1; parameter < indicator;
         parameter++) {
      (*decrements)[parameter] = ++decrement;
    }
    previous_indicator = indicator;
  }
  for (int parameter = previous_indicator + 1; parameter <= num_vars;
       parameter++) {
    (*decrements)[parameter] = ++decrement;
  }
  return num_vars;
}

// Read the CNF file, translating variable names, removing some clauses and
// turning some other clauses into weight lines.
int ParseCnf(std::string cnf_filename, int num_vars,
             const std::map<int, int> &decrements,
             std::vector<std::vector<int>> *new_literals,
             std::vector<int> *new_parameters,
             std::map<int, std::string> *weights) {
  std::ifstream cnf_file(cnf_filename);
  int num_clauses = 0;
  std::string line;
  while (std::getline(cnf_file, line)) {
    std::istringstream iss(line);
    std::string token;
    iss >> token;
    if (token == "c") {
      iss >> token;
      for (int i = 1; i <= 2 * num_vars; i++) {
        iss >> token;
        int variable = (i+1)/2;
        if (i % 2 == 1 && decrements.find(variable) != decrements.end()) {
          (*weights)[variable] = token;
        }
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
          literals.push_back(literal);
        }
        iss >> token;
      }
      if (line_type != Skip) {
        new_literals->push_back(literals);
        new_parameters->push_back(parameter_variable);
        if (!literals.empty()) {
          num_clauses++;
        }
      }
    }
  }
  return num_clauses;
}

// Let's not use two 'bits' to represent two possible values
std::vector<std::string> MergeVariables(std::map<int, int> *decrements,
                                        std::vector<std::vector<int>> *new_literals,
                                        std::vector<int> *new_parameters,
                                        int *num_clauses,
                                        std::map<int, std::string> *weights) {
  std::vector<std::string> new_weights;
  assert(new_literals->size() == new_parameters->size());
  for (size_t i = 0; i < new_literals->size() - 1; i++) {
    if ((*new_parameters)[i] == 0 && (*new_parameters)[i+1] == 0 &&
        (*new_literals)[i].size() == 2 && (*new_literals)[i+1].size() == 2 &&
        (((*new_literals)[i+1][0] == -(*new_literals)[i][0] &&
          (*new_literals)[i+1][1] == -(*new_literals)[i][1]) ||
         ((*new_literals)[i+1][0] == -(*new_literals)[i][1] &&
          (*new_literals)[i+1][1] == -(*new_literals)[i][0]))) {
      int num_to_remove = 2;
      int a = std::min(std::abs((*new_literals)[i][0]),
                       std::abs((*new_literals)[i][1]));
      int b = std::max(std::abs((*new_literals)[i][0]),
                       std::abs((*new_literals)[i][1]));
      if (i + 3 < new_parameters->size() &&
          (*new_parameters)[i+2] != 0 && (*new_parameters)[i+3] != 0 &&
          (*new_literals)[i+2].size() == 1 && (*new_literals)[i+3].size() == 1) {
        num_to_remove = 4;

        // Determine the weights of a and b
        std::string a_weight;
        std::string b_weight;
        if ((*new_literals)[i+2][0] == -a && (*new_literals)[i+3][0] == -b) {
          a_weight = (*weights)[(*new_parameters)[i+2]];
          b_weight = (*weights)[(*new_parameters)[i+3]];
        } else if ((*new_literals)[i+2][0] == -b && (*new_literals)[i+3][0] == -a) {
          a_weight = (*weights)[(*new_parameters)[i+3]];
          b_weight = (*weights)[(*new_parameters)[i+2]];
        } else {
          continue;
        }

        // Add a new clause
        // NOTE: we assume that all variables that are due to be removed that
        // are smaller than 'a' have already been added to 'decrements'
        std::ostringstream oss;
        oss << "w " << RenameLiteral(a, *decrements) << " " << a_weight << " "
            << b_weight;
        new_weights.push_back(oss.str());
        num_clauses++;
      }
      Rename(b, (((*new_literals)[i][0] < 0 && (*new_literals)[i][1] < 0) ||
                 ((*new_literals)[i][0] > 0 && (*new_literals)[i][1] > 0)) ? -a : a,
             new_literals);
      AddToDecrements(b, decrements);

      // Remove clauses
      num_clauses -= num_to_remove;
      new_literals->erase(new_literals->begin() + i,
                          new_literals->begin() + i + num_to_remove);
      new_parameters->erase(new_parameters->begin() + i,
                            new_parameters->begin() + i + num_to_remove);
      i--;
    }
  }
  return new_weights;
}

// Compile and output the new encoding
void OutputEncoding(std::string cnf_filename, int num_clauses, int num_vars,
                    const std::map<int, int> &decrements,
                    const std::vector<std::vector<int>> &new_literals,
                    const std::vector<int> &new_parameters,
                    const std::vector<std::string> &new_weights,
                    std::map<int, std::string> *weights) {
  std::ofstream output(cnf_filename);
  output << "p cnf " << num_vars - decrements.size() << " " << num_clauses
         << std::endl;
  double premultiplication_constant = 1;
  for (size_t i = 0; i < new_literals.size(); i++) {
    if (new_parameters[i] == 0) {
      for (int literal : new_literals[i]) {
        output << RenameLiteral(literal, decrements) << " ";
      }
      output << "0" << std::endl;
    } else if (new_literals[i].empty()) {
      premultiplication_constant *= std::stod((*weights)[new_parameters[i]]);
    } else {
      output << "w";
      for (int literal : new_literals[i]) {
        output << " " << RenameLiteral(-literal, decrements);
      }
      output << " " << (*weights)[new_parameters[i]] << " 1" << std::endl;
    }
  }
  for (const std::string &weight_line : new_weights) {
    output << weight_line << std::endl;
  }
  if (premultiplication_constant != 1) {
    output << "w 0 " << premultiplication_constant << std::endl;
  }
}

int main(int argc, char *argv[]) {
  cxxopts::Options options("cnf4dpmc", "Modify a CNF encoding produced by Ace to optimise it for DPMC");
  options.add_options()("f,filename", "a Bayesian network",
                        cxxopts::value<std::string>());
  auto result = options.parse(argc, argv);
  if (result.count("filename") == 0) {
    std::cout << options.help() << std::endl;
    exit(0);
  }
  std::string bn_filename = result["filename"].as<std::string>();
  std::string cnf_filename = bn_filename + ".cnf";

  std::map<int, int> decrements;
  int num_vars = CreateDecrements(bn_filename, &decrements);

  std::map<int, std::string> weights;
  std::vector<std::vector<int>> new_literals;
  std::vector<int> new_parameters;
  int num_clauses = ParseCnf(cnf_filename, num_vars, decrements, &new_literals,
                             &new_parameters, &weights);

  // Weight lines with weight = 1 can be removed
  for (size_t i = 0; i < new_literals.size(); i++) {
    if (new_parameters[i] != 0 && !new_literals[i].empty() &&
        std::stod(weights[new_parameters[i]]) == 1) {
      new_parameters.erase(new_parameters.begin() + i);
      new_literals.erase(new_literals.begin() + i);
      i--;
      num_clauses--;
    }
  }

  auto new_weights = MergeVariables(&decrements, &new_literals, &new_parameters,
                                    &num_clauses, &weights);
  OutputEncoding(cnf_filename, num_clauses, num_vars, decrements, new_literals,
                 new_parameters, new_weights, &weights);
}
