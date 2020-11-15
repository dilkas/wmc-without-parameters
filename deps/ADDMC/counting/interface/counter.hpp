#pragma once

/* includes *******************************************************************/

#include "formula.hpp"
#include "visual.hpp"

/* namespaces *****************************************************************/

namespace dd {
  double getTerminalValue(const ADD &terminal);
  double countConstAddFloat(const ADD &add);
  int_t countConstAddInt(const ADD &add);
  void printMaxAddVarCount(int_t maxAddVarCount);
}

/* classes ********************************************************************/

class Counter { /* abstract */
protected:
  int_t dotFileIndex = 1;
  Cudd *mgr;
  MapT<int_t, int_t> formulaVarToAddVarMap; /* e.g. {42: 0, 13: 1} */
  VectorT<int_t> addVarToFormulaVarMap; /* e.g. [42, 13], i.e. addVarOrdering */

  void writeDotFile(ADD &add, std::string dotFileDir = DOT_DIR);
  template<typename T> SetT<int_t> getFormulaVars(const T &addVars) {
    SetT<int_t> formulaVars;
    for (int_t addVar : addVars) formulaVars.insert(addVarToFormulaVarMap.at(addVar));
    return formulaVars;
  }
  const VectorT<int_t> &getAddVarOrdering() const; /* addVarToFormulaVarMap */
  void orderAddVars(Formula &formula); /* writes: formulaVarToAddVarMap, addVarToFormulaVarMap */
  ADD getClauseAdd(const VectorT<int_t> &clause);
  void abstract(ADD &add, int_t addVar, const MapT<int_t, double> &literalWeights, const WeightFormat weightFormat);
  void abstractCube(ADD &add, const SetT<int_t> &addVars, const MapT<int_t, double> &literalWeights,
                    const WeightFormat weightFormat);

public:
  virtual double count(Formula &formula) = 0;
};

class MonolithicCounter : public Counter { /* builds an ADD for the entire CNF */
protected:
  void setMonolithicClauseAdds(VectorT<ADD> &clauseAdds, Formula &formula);
  void setCnfAdd(ADD &cnfAdd, Formula &formula);

public:
  double count(Formula &formula);
  MonolithicCounter(Cudd *mgr);
};

class FactoredCounter : public Counter {}; /* abstract; builds an ADD for each clause */

class LinearCounter : public FactoredCounter { /* combines adjacent clauses */
protected:
  void setLinearClauseAdds(VectorT<ADD> &clauseAdds, Formula &formula);

public:
  double count(Formula &formula);
  LinearCounter(Cudd *mgr);
};

class NonlinearCounter : public FactoredCounter { /* abstract; puts clauses in clusters */
protected:
  bool clusterTree;
  VarOrderingHeuristic formulaVarOrderingHeuristic;
  bool inverseFormulaVarOrdering;
  VectorT<VectorT<int_t>> clusters; /* clusterIndex |-> clauseIndices */
  VectorT<VectorT<ADD>> addClusters; /* clusterIndex |-> adds (for cluster tree) */
  VectorT<SetT<int_t>> projectingAddVarSets; /* clusterIndex |-> addVars (for cluster tree) */

  SetT<int_t> getProjectingAddVars(int_t clusterIndex, bool minRank, const VectorT<int_t> &formulaVarOrdering,
                                   const VectorT<VectorT<int_t>> &cnf, const MapT<int_t, VectorT<int_t>> &dependencies);
  void printClusters(const VectorT<VectorT<int_t>> &cnf, const MapT<int_t, VectorT<int_t>> &dependencies) const;
  void fillClusters(const VectorT<VectorT<int_t>> &cnf, const MapT<int_t, VectorT<int_t>> &dependencies,
                    const VectorT<int_t> &formulaVarOrdering, bool minRank);
  /* (for cluster tree) */
  void fillAddClusters(const VectorT<VectorT<int_t>> &cnf, const MapT<int_t, VectorT<int_t>> &dependencies,
                       const MapT<int_t, ADD> &weights, const VectorT<int_t> &formulaVarOrdering, bool minRank);
  void fillProjectingAddVarSets(const VectorT<VectorT<int_t>> &cnf, const MapT<int_t, VectorT<int_t>> &dependencies,
                                const MapT<int_t, ADD> &weights, const VectorT<int_t> &formulaVarOrdering,
                                bool minRank); /* (for cluster tree) */
  int_t getNewClusterIndex(const ADD &abstractedClusterAdd, const VectorT<int_t> &formulaVarOrdering, bool minRank); /* returns DUMMY_MAX_INT if no var remains (for cluster tree) */
  double countWithList(Formula &formula, bool minRank);
  double countWithTree(Formula &formula, bool minRank);
};

class BucketCounter : public NonlinearCounter { /* bucket elimination */
public:
  double count(Formula &formula);
  BucketCounter(
    Cudd *mgr,
    bool clusterTree,
    VarOrderingHeuristic formulaVarOrderingHeuristic,
    bool inverseFormulaVarOrdering);
};

class BouquetCounter : public NonlinearCounter { /* Bouquet's Method */
public:
  double count(Formula &formula);  /* #MAVC */
  BouquetCounter(
    Cudd *mgr,
    bool clusterTree,
    VarOrderingHeuristic formulaVarOrderingHeuristic,
    bool inverseFormulaVarOrdering);
};
