#include <cassert>
#include <fstream>

#include "../../deps/cxxopts.hpp"

int num_vars = 0;
int num_disabled = 0;
double premultiplication_constant = 1;
std::map<int, int> decrements;
std::vector<std::string> weights;
std::vector<std::string> new_weights;
std::vector<std::vector<int>> clauses;
// A positive integer points to the parameter variable that holds the weights
// associated with this weight line. 0 represents a clause. -1 represents a
// skipped/disabled clause.
std::vector<int> new_parameters;

std::string GetWeight(int literal) {
  if (literal > 0) {
    return weights[2 * literal - 2];
  }
  return weights[-2 * literal - 1];
}

int RenameLiteral(int literal) {
  if (literal < 0) {
    return -RenameLiteral(-literal);
  }
  if (decrements.empty() || literal < decrements.begin()->first) {
    return literal;
  }
  auto it = decrements.upper_bound(literal);
  int new_literal = literal - std::prev(it)->second;
  assert(new_literal > 0);
  return new_literal;
}

// Read the LMAP file, creating a map of decrements
void ParseLmap(std::string filename) {
  std::ifstream lmap_file(filename.substr(0, filename.length() - 3) + "lmap");
  std::string line;
  int previous_indicator = 0;
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
    for (int i = previous_indicator + 1; i < indicator; i++) {
      decrements[i] = ++decrement;
    }
    previous_indicator = indicator;
  }
  for (int i = previous_indicator + 1; i <= num_vars; i++) {
    decrements[i] = ++decrement;
  }
}

void ParseWeights(std::istringstream &iss, bool fill_decrements) {
  int previous_indicator = 0;
  int decrement = 0;
  for (int i = 0; i < 2 * num_vars; i++) {
    std::string token;
    iss >> token;
    weights.push_back(token);
    if (fill_decrements && i % 2 == 1 && std::stod(weights[i-1]) == 1 &&
        std::stod(weights[i]) == 1) {
      int indicator = i/2+1;
      for (int j = previous_indicator + 1; j < indicator; j++) {
        decrements[j] = ++decrement;
      }
      previous_indicator = indicator;
    }
  }
  if (fill_decrements) {
    for (int i = previous_indicator + 1; i <= num_vars; i++) {
      decrements[i] = ++decrement;
    }
  }
  if (iss.good()) {
    iss >> premultiplication_constant;
  }
}

void ParseCnf(std::string filename, bool fill_decrements) {
  std::ifstream cnf_file(filename);
  std::string line;
  while (std::getline(cnf_file, line)) {
    std::istringstream iss(line);
    std::string token;
    iss >> token;
    if (token[0] == 'p') {
      iss >> token;
      iss >> num_vars;
    } else if (token[0] == 'c') {
      iss >> token;
      if (token == "weights") {
        ParseWeights(iss, fill_decrements);
      }
    } else {
      std::vector<int> literals;
      while (token != "0") {
        literals.push_back(std::stoi(token));
        iss >> token;
      }
      clauses.push_back(literals);
    }
  }
}

void Transform() {
  for (size_t i = 0; i < clauses.size(); i++) {
    int parameter_variable = 0;
    for (auto literal : clauses[i]) {
      if (literal < 0 && decrements.find(-literal) != decrements.end()) {
        parameter_variable = -1;
        num_disabled++;
        break;
      }
      if (literal > 0 && decrements.find(literal) != decrements.end()) {
        parameter_variable = literal;
        if (clauses[i].size() == 1) {
          num_disabled++;
        }
        break;
      }
    }
    new_parameters.push_back(parameter_variable);
  }
}

// Compile and output the new encoding
void OutputEncoding(std::string filename) {
  std::ofstream output(filename);
  output << "p cnf " << num_vars - decrements.size() << " "
         << clauses.size() + new_weights.size() - num_disabled << std::endl;
  for (size_t i = 0; i < clauses.size(); i++) {
    if (new_parameters[i] < 0) {
      continue;
    }
    if (new_parameters[i] == 0) {
      for (int literal : clauses[i]) {
        output << RenameLiteral(literal) << " ";
      }
      output << "0" << std::endl;
    } else if (clauses[i].size() == 1) {
      premultiplication_constant *= std::stod(GetWeight(new_parameters[i]));
    } else {
      output << "w";
      for (int literal : clauses[i]) {
        if (literal != new_parameters[i]) {
          output << " " << RenameLiteral(-literal);
        }
      }
      output << " " << GetWeight(new_parameters[i]) << " 1" << std::endl;
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
  options.add_options()
    ("f,filename", "the filename of a CNF encoding of a Bayesian network",
     cxxopts::value<std::string>())
    ("l,lmap", "parse the LMAP file (as generated by Ace)",
     cxxopts::value<bool>()->default_value("false"))
    ;
  auto result = options.parse(argc, argv);
  if (result.count("filename") == 0) {
    std::cout << options.help() << std::endl;
    exit(0);
  }
  std::string filename = result["filename"].as<std::string>();
  bool parse_lmap = result["lmap"].as<bool>();

  if (parse_lmap) {
    ParseLmap(filename);
  }
  ParseCnf(filename, !parse_lmap);
  Transform();

  // Weight lines with weight = 1 can be removed
  for (size_t i = 0; i < clauses.size(); i++) {
    if (new_parameters[i] > 0 && !clauses[i].empty() &&
        std::stod(GetWeight(new_parameters[i])) == 1) {
      new_parameters[i] = -1;
      num_disabled++;
    }
  }

  // Merge two weight lines into one
  for (size_t i = 0; i < clauses.size() - 1; i++) {
    if (new_parameters[i] > 0 && new_parameters[i+1] > 0 &&
        clauses[i].size() == 2 && clauses[i+1].size() == 2 &&
        clauses[i+1][0] == -clauses[i][0]) {
      int positive_parameter = (clauses[i][0] < 0) ?
        new_parameters[i] : new_parameters[i+1];
      int negative_parameter = (clauses[i][0] < 0) ?
        new_parameters[i+1] : new_parameters[i];
      int variable = RenameLiteral(std::abs(clauses[i][0]));
      new_weights.push_back("w " + std::to_string(variable) + " " +
                            GetWeight(positive_parameter) + " " +
                            GetWeight(negative_parameter));
      new_parameters[i] = -1;
      new_parameters[++i] = -1;
      num_disabled += 2;
    }
  }
  OutputEncoding(filename);
}
