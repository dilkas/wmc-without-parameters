#pragma once

/* inclusions *****************************************************************/

#include <assert.h>
#include "graph.hpp"

/* constants ******************************************************************/

extern const string &CNF_WORD;
extern const string &WCNF_WORD;
extern const string &WEIGHTS_WORD; // MINIC2D weight line
extern const string &WEIGHT_WORD; // CACHET or MCC weight lines
extern const string &LINE_END_WORD; // required for clause lines and optional for MCC weight lines

extern const Float CACHET_DEFAULT_VAR_WEIGHT;
extern const Float MCC_DEFAULT_LITERAL_WEIGHT;

/* classes ********************************************************************/

class Label : public vector<Int> { // lexicographic search
public:
  void addNumber(Int i); // retains descending order
};

class Cnf {
protected:
  WeightFormat weightFormat;
  Int declaredVarCount = DUMMY_MIN_INT; // in cnf file
  Map<Int, Float> literalWeights;
  vector<ADD> weights; /* conditional probability tables encoded as ADDs */
  vector<vector<Int>> dependencies; /* how variables depend on other variables */
  vector<vector<Int>> clauses;
  vector<Int> apparentVars; // vars appearing in clauses, ordered by 1st appearance
  vector<vector<std::string>> unparsedWeights; /* needed to compute variable ordering heuristics */
  vector<Int> varOrdering;

  ADD literalToDd(Int literal, Cudd *mgr);
  ADD constructDdFromWords(Cudd *mgr, Int var, const vector<std::string> &words);
  void updateApparentVars(Int literal); // adds var to apparentVars
  void addClause(const vector<Int> &clause); // writes: clauses, apparentVars
  Graph getGaifmanGraph() const;
  vector<Int> generateVarOrdering(VarOrderingHeuristic varOrderingHeuristic,
                                  bool inverse) const;
  vector<Int> getAppearanceVarOrdering() const;
  vector<Int> getDeclarationVarOrdering() const;
  vector<Int> getRandomVarOrdering() const;
  vector<Int> getMcsVarOrdering() const;
  vector<Int> getLexpVarOrdering() const;
  vector<Int> getLexmVarOrdering() const;
  vector<Int> getMinFillVarOrdering() const;

public:
  vector<Int> getVarOrdering() const;
  Int getDeclaredVarCount() const;
  Map<Int, Float> getLiteralWeights() const;
  const vector<ADD> &getWeights() const;
  WeightFormat getWeightFormat() const;
  const vector<vector<Int>> &getDependencies() const;
  Int getEmptyClauseIndex() const; // first (nonnegative) index if found else DUMMY_MIN_INT
  const vector<vector<Int>> &getClauses() const;
  const vector<Int> &getApparentVars() const;
  void printLiteralWeights() const;
  void printClauses() const;
  void printWeightedFormula(const WeightFormat &outputWeightFormat) const;
  Cnf(const vector<vector<Int>> &clauses);
  Cnf(const string &filePath, WeightFormat weightFormat, Cudd *mgr,
      VarOrderingHeuristic varOrderingHeuristic, bool inverse);
};
