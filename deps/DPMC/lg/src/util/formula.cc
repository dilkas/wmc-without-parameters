/******************************************
Copyright (c) 2020, Jeffrey Dudek
******************************************/

#include "util/formula.h"

#include <algorithm>
#include <string_view>

#include "util/dimacs_parser.h"

namespace util {
  bool Formula::add_clause(std::vector<int> literals) {
    for (int literal : literals) {
      if (literal == 0 || static_cast<size_t>(abs(literal)) > num_variables_) {
        return false;
      }
    }

    clauses_.push_back(literals);
    clause_variables_.push_back(std::vector<size_t>());
    clause_variables_.back().reserve(literals.size());
    for (int literal : literals) {
      clause_variables_.back().push_back(abs(literal));
    }

    std::sort(clause_variables_.back().begin(), clause_variables_.back().end());
    clause_variables_.back().erase(std::unique(clause_variables_.back().begin(),
                                               clause_variables_.back().end()),
                                   clause_variables_.back().end());
    return true;
  }

  std::optional<Formula> Formula::parse_DIMACS(std::istream *stream) {
    util::DimacsParser parser(stream);

    // Parse the header
    std::vector<double> entries;
    if (!parser.parseExpectedLine("p cnf", &entries) || entries.size() != 2) {
      return std::nullopt;
    }

    Formula result(static_cast<int>(entries[0]));
    int num_clauses_to_parse = entries[1];

    // Parse the remaining clauses
    while (!parser.finished()) {
      entries.clear();
      std::string prefix = parser.parseLine(&entries);

      if (prefix == "w" && entries.size() == 2) {
        continue;  // Ignore weight lines
      } else if (prefix == "") {
        // [x] [y] ... [z] 0 indicates a clause with literals (x, y, ..., z)
        if (entries.size() == 0 || entries.back() != 0) {
          return std::nullopt;
        }

        // Clause lines end in a trailing 0, so remove it
        std::vector<int> clause(entries.begin(),
                    std::prev(entries.end()));
        if (!result.add_clause(clause)) {
            return std::nullopt;
        }
        num_clauses_to_parse--;
      } else {
          // Unknown line
          return std::nullopt;
      }
    }

    // Verify that we have parsed the correct number of clauses
    if (num_clauses_to_parse != 0) {
        return std::nullopt;
    }

    return result;
  }

  void Formula::write_line_graph(std::ostream *output) const {
    size_t edge_count = 0;
    for (const std::vector<int> &clause : clauses_) {
      edge_count += (clause.size() * (clause.size()-1)) / 2;
    }

    *output << "p tw " << num_variables_ << " " << edge_count << "\n";

    for (const std::vector<int> &clause : clauses_) {
      for (size_t i = 0; i < clause.size(); i++) {
        for (size_t j = i+1; j < clause.size(); j++) {
          *output << abs(clause[i]) << " ";
          *output << abs(clause[j]) << "\n";
        }
      }
    }
  }
}  // namespace util
