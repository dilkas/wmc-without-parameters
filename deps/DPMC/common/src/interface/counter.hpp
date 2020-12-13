#pragma once

/* inclusions *****************************************************************/

#include "formula.hpp"
#include "join.hpp"
#include "visual.hpp"

/* namespaces *****************************************************************/

namespace diagram {
  Float getTerminalValue(const ADD &terminal);
  Float countConstDdFloat(const ADD &dd);
  Int countConstDdInt(const ADD &dd);
  void printMaxDdVarCount(Int maxDdVarCount);
}

/* classes ********************************************************************/

class Counter { // abstract
protected:
  Int dotFileIndex = 1;
  Cudd *mgr;
  Map<Int, Int> cnfVarToDdVarMap; // e.g. {42: 0, 13: 1}
  vector<Int> ddVarToCnfVarMap; // e.g. [42, 13], i.e. ddVarOrdering

  JoinNonterminal *joinRoot;

  static void handleSignals(int signal); // `timeout` sends SIGTERM

  void writeDotFile(ADD &dd, const string &dotFileDir = DOT_DIR);
  template<typename T> Set<Int> getCnfVars(const T &ddVars) {
    Set<Int> cnfVars;
    for (Int ddVar : ddVars) cnfVars.insert(ddVarToCnfVarMap.at(ddVar));
    return cnfVars;
  }
  const vector<Int> &getDdVarOrdering() const; // ddVarToCnfVarMap
  void orderDdVars(Cnf &cnf); // writes: cnfVarToDdVarMap, ddVarToCnfVarMap
  void abstract(ADD &dd, Int ddVar, const Map<Int, Float> &literalWeights,
                WeightFormat weightFormat);
  void abstractCube(ADD &dd, const Set<Int> &ddVars,
                    const Map<Int, Float> &literalWeights,
                    WeightFormat weightFormat);

  void printJoinTree(const Cnf &cnf) const;

public:
  virtual void constructJoinTree(const Cnf &cnf) = 0; // handles cnf without empty clause
  void setJoinTree(const Cnf &cnf); // handles cnf with/without empty clause

  ADD countSubtree(JoinNode *joinNode, const Cnf &cnf, Set<Int> &projectedCnfVars); // handles cnf without empty clause
  Float countJoinTree(Cnf &cnf); // handles cnf with/without empty clause

  virtual Float computeModelCount(Cnf &cnf) = 0; // handles cnf without empty clause
  Float getModelCount(Cnf &cnf); // handles cnf with/without empty clause

  void output(Cnf &cnf, OutputFormat outputFormat);
};

class JoinTreeCounter : public Counter {
protected:
  VarOrderingHeuristic cnfVarOrderingHeuristic;
  bool inverseCnfVarOrdering;
public:
  void constructJoinTree(const Cnf &cnf) override;
  Float computeModelCount(Cnf &cnf) override;
  JoinTreeCounter(
    Cudd *mgr,
    JoinNonterminal *joinRoot,
    VarOrderingHeuristic ddVarOrderingHeuristic,
    bool inverseDdVarOrdering
  );
};

class MonolithicCounter : public Counter { // builds an ADD for the entire CNF
protected:
  void setMonolithicClauseDds(vector<ADD> &clauseDds, Cnf &cnf);
  void setCnfDd(ADD &cnfDd, Cnf &cnf);

public:
  void constructJoinTree(const Cnf &cnf) override;
  Float computeModelCount(Cnf &cnf) override;
  MonolithicCounter(Cudd *mgr);
};

class FactoredCounter : public Counter {}; // abstract; builds an ADD for each clause

class LinearCounter : public FactoredCounter { // combines adjacent clauses
protected:
  vector<Set<Int>> projectableCnfVarSets; // clauseIndex |-> cnfVars

  void fillProjectableCnfVarSets(const vector<Constraint*> &clauses,
                                 const vector<vector<Int>> &dependencies);
  void setLinearClauseDds(vector<ADD> &clauseDds, Cnf &cnf);

public:
  void constructJoinTree(const Cnf &cnf) override;
  Float computeModelCount(Cnf &cnf) override;
  LinearCounter(Cudd *mgr);
};

class NonlinearCounter : public FactoredCounter { // abstract; puts clauses in clusters
protected:
  bool usingTreeClustering;
  VarOrderingHeuristic cnfVarOrderingHeuristic;
  bool inverseCnfVarOrdering;
  vector<vector<Int>> clusters; // clusterIndex |-> clauseIndices

  vector<Set<Int>> occurrentCnfVarSets; // clusterIndex |-> cnfVars
  vector<Set<Int>> projectableCnfVarSets; // clusterIndex |-> cnfVars
  vector<vector<JoinNode *>> joinNodeSets; // clusterIndex |-> non-null nodes

  vector<vector<ADD>> ddClusters; // clusterIndex |-> ADDs (if usingTreeClustering)
  vector<Set<Int>> projectingDdVarSets; // clusterIndex |-> ddVars (if usingTreeClustering)

  void printClusters(const vector<Constraint*> &clauses,
                     const vector<vector<Int>> &dependencies) const;
  void fillClusters(const vector<Constraint*> &clauses,
                    const vector<vector<Int>> &dependencies,
                    const vector<Int> &cnfVarOrdering, bool usingMinVar);

  void printOccurrentCnfVarSets() const;
  void printProjectableCnfVarSets() const;
  // writes: occurrentCnfVarSets, projectableCnfVarSets
  void fillCnfVarSets(const vector<Constraint*> &clauses,
                      const vector<vector<Int>> &dependencies,
                      bool usingMinVar);

  Set<Int> getProjectingDdVars(Int clusterIndex, bool usingMinVar,
                               const vector<Int> &cnfVarOrdering,
                               const vector<Constraint*> &clauses,
                               const vector<vector<Int>> &dependencies);
  // (if usingTreeClustering)
  void fillDdClusters(const vector<Constraint*> &clauses,
                      const vector<vector<Int>> &dependencies,
                      const vector<ADD> &weights,
                      const vector<Int> &cnfVarOrdering, bool usingMinVar);
  void fillProjectingDdVarSets(const vector<Constraint*> &clauses,
                               const vector<vector<Int>> &dependencies,
                               const vector<ADD> &weights,
                               const vector<Int> &cnfVarOrdering,
                               bool usingMinVar); // (if usingTreeClustering)

  Int getTargetClusterIndex(Int clusterIndex) const; // returns DUMMY_MAX_INT if no var remains
  Int getNewClusterIndex(const ADD &abstractedClusterDd, const vector<Int> &cnfVarOrdering, bool usingMinVar) const; // returns DUMMY_MAX_INT if no var remains (if usingTreeClustering)
  Int getNewClusterIndex(const Set<Int> &remainingDdVars) const; // returns DUMMY_MAX_INT if no var remains (if usingTreeClustering) #MAVC

  void constructJoinTreeUsingListClustering(const Cnf &cnf, bool usingMinVar);
  void constructJoinTreeUsingTreeClustering(const Cnf &cnf, bool usingMinVar);

  Float countUsingListClustering(Cnf &cnf, bool usingMinVar);
  Float countUsingTreeClustering(Cnf &cnf, bool usingMinVar);
  Float countUsingTreeClustering(Cnf &cnf); // #MAVC
};

class BucketCounter : public NonlinearCounter { // bucket elimination
public:
  void constructJoinTree(const Cnf &cnf) override;
  Float computeModelCount(Cnf &cnf) override;
  BucketCounter(
    Cudd *mgr,
    bool usingTreeClustering,
    VarOrderingHeuristic cnfVarOrderingHeuristic,
    bool inverseCnfVarOrdering);
};

class BouquetCounter : public NonlinearCounter { // Bouquet's Method
public:
  void constructJoinTree(const Cnf &cnf) override;
  Float computeModelCount(Cnf &cnf) override;
  BouquetCounter(
    Cudd *mgr,
    bool usingTreeClustering,
    VarOrderingHeuristic cnfVarOrderingHeuristic,
    bool inverseCnfVarOrdering);
};

Set<Int> getClusterCnfVars(const vector<Int> &cluster,
                           const vector<Constraint*> &clauses,
                           const vector<vector<Int>> &dependencies);