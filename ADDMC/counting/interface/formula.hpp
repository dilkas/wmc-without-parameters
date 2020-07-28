#pragma once

/* includes *******************************************************************/

#include "graph.hpp"

/* constants ******************************************************************/

const int_t DIMACS_CLAUSE_LINE_END = 0;

const std::string CACHET_WEIGHT_WORD = "w"; /* starting a Cachet weight line */
const std::string MINIC2D_WEIGHT_WORD = "weights"; /* following "c" in a miniC2D weight line */

const std::string DIMACS_PROBLEM_WORD = "p";
const std::string DIMACS_CNF_WORD = "cnf";
const std::string DIMACS_COMMENT_WORD = "c";

/* classes ********************************************************************/

class Label : public VectorT<int_t> { /* lexicographic search */
public:
  void addNumber(int_t i); /* retains descending order */
};

class Formula {
protected:
  WeightFormat weightFormat;
  int_t declaredVarCount = DUMMY_MIN_INT; /* in DIMACS file */
  MapT<int_t, double> literalWeights;
  MapT<int_t, ADD> weights; /* conditional probability tables encoded as ADDs */
  MapT<int_t, VectorT<int_t>> dependencies; /* how variables depend on other variables */
  VectorT<VectorT<int_t>> cnf;
  VectorT<int_t> apparentVars; /* vars appearing in cnf, ordered by 1st appearance */
  VectorT<VectorT<std::string>> unparsedWeights; /* needed to compute variable ordering heuristics */
  VectorT<int_t> varOrdering;

  ADD literalToADD(int_t literal, Cudd *mgr);
  ADD constructADDFromWords(Cudd *mgr, int_t var, VectorT<std::string> words);
  void updateApparentVars(int_t literal);       /* adds var to apparentVars */
  void addClause(const VectorT<int_t> &clause); /* writes: cnf, apparentVars */
  Graph getGaifmanGraph() const;
  VectorT<int_t> generateVarOrdering(VarOrderingHeuristic varOrderingHeuristic, bool inverse) const;
  VectorT<int_t> getAppearanceVarOrdering() const;
  VectorT<int_t> getDeclarationVarOrdering() const;
  VectorT<int_t> getRandomVarOrdering() const;
  VectorT<int_t> getLexpVarOrdering() const;
  VectorT<int_t> getLexmVarOrdering() const;
  VectorT<int_t> getMcsVarOrdering() const;

public:
  VectorT<int_t> getVarOrdering() const;
  int_t getDeclaredVarCount() const;
  MapT<int_t, double> getLiteralWeights() const;
  const MapT<int_t, ADD> &getWeights() const;
  const MapT<int_t, VectorT<int_t>> &getDependencies() const;
  const VectorT<VectorT<int_t>> &getCnf() const;
  WeightFormat getWeightFormat() const;
  void printLiteralWeights() const;
  void printCnf() const;
  Formula(const std::string &filePath, WeightFormat weightFormat, Cudd *mgr,
          VarOrderingHeuristic varOrderingHeuristic, bool inverse);
};