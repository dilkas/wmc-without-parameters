/* inclusions *****************************************************************/

#include "../interface/counter.hpp"

/* namespaces *****************************************************************/

/* namespace dd ***************************************************************/

Float diagram::getTerminalValue(const ADD &terminal) {
  DdNode *node = terminal.getNode();
  return (node -> type).value;
}

Float diagram::countConstDdFloat(const ADD &dd) {
  ADD minTerminal = dd.FindMin();
  ADD maxTerminal = dd.FindMax();

  Float minValue = getTerminalValue(minTerminal);
  Float maxValue = getTerminalValue(maxTerminal);

  if (minValue != maxValue) {
    showError("ADD is nonconst: min value " + to_string(minValue) +
      ", max value " + to_string(maxValue));
  }

  return minValue;
}

Int diagram::countConstDdInt(const ADD &dd) {
  Float value = countConstDdFloat(dd);

  if (!util::isInt(value)) showError("unweighted model count is not int");

  return value;
}

void diagram::printMaxDdVarCount(Int maxDdVarCount) {
  util::printRow("maxAddVarCount", maxDdVarCount);
}

/* classes ********************************************************************/

/* class Counter **************************************************************/

void Counter::handleSignals(int signal) {
  cout << "\n";
  util::printDuration(startTime);
  cout << "\n";
  util::printSolutionLine(0, 0, 0);
  showError("received OS signal " + to_string(signal) + "; printed dummy model count");
}

void Counter::writeDotFile(ADD &dd, const string &dotFileDir) {
  writeDd(*mgr, dd, dotFileDir + "dd" + to_string(dotFileIndex) + ".dot");
  dotFileIndex++;
}

const vector<Int> &Counter::getDdVarOrdering() const {
  return ddVarToCnfVarMap;
}

void Counter::orderDdVars(Cnf &cnf) {
  ddVarToCnfVarMap = cnf.getVarOrdering();
  for (size_t ddVar = 0; ddVar < ddVarToCnfVarMap.size(); ddVar++) {
    Int cnfVar = ddVarToCnfVarMap.at(ddVar);
    cnfVarToDdVarMap[cnfVar] = ddVar;
    mgr->addVar(ddVar); // creates ddVar-th ADD var
  }
}

void Counter::abstract(ADD &dd, Int ddVar,
                       const Map<Int, Float> &literalWeights,
                       WeightFormat weightFormat) {
  if (weightFormat != WeightFormat::CONDITIONAL) {
    Int cnfVar = ddVarToCnfVarMap.at(ddVar);
    ADD positiveWeight = mgr->constant(literalWeights.at(cnfVar));
    ADD negativeWeight = mgr->constant(literalWeights.at(-cnfVar));

    dd = positiveWeight * dd.Compose(mgr->addOne(), ddVar) +
         negativeWeight * dd.Compose(mgr->addZero(), ddVar);
  } else {
    dd = dd.Compose(mgr->addOne(), ddVar) + dd.Compose(mgr->addZero(), ddVar);
  }
}

void Counter::abstractCube(ADD &dd, const Set<Int> &ddVars,
                           const Map<Int, Float> &literalWeights,
                           WeightFormat weightFormat) {
  for (Int ddVar :ddVars) {
    abstract(dd, ddVar, literalWeights, weightFormat);
  }
}

void Counter::printJoinTree(const Cnf &cnf) const {
  cout << PROBLEM_WORD << " " << JT_WORD << " " << cnf.getDeclaredVarCount() << " " << joinRoot->getTerminalCount() << " " << joinRoot->getNodeCount() << "\n";
  joinRoot->printSubtree();
}

void Counter::setJoinTree(const Cnf &cnf) {
  if (cnf.getClauses().empty()) { // empty cnf
    // showWarning("cnf is empty"); // different warning for empty clause
    joinRoot = new JoinNonterminal(vector<JoinNode *>());
    return;
  }

  Int i = cnf.getEmptyClauseIndex();
  if (i != DUMMY_MIN_INT) { // empty clause found
    showWarning("clause " + to_string(i + 1) + " of cnf is empty (1-indexing); generating dummy join tree");
    joinRoot = new JoinNonterminal(vector<JoinNode *>());
  }
  else {
    constructJoinTree(cnf);
  }
}

ADD Counter::countSubtree(JoinNode *joinNode, const Cnf &cnf, Set<Int> &projectedCnfVars) {
  if (joinNode->isTerminal()) {
    auto i = joinNode->getNodeIndex();
    auto clauses = cnf.getClauses();
    return clauses.at(i)->getDD(mgr, cnfVarToDdVarMap);
  }
  else {
    ADD dd = mgr->addOne();
    bool greedy = true;
    //greedy = false; // non-greedy in CP-2020 experiments
    if (greedy) { // iteratively multiplies 2 smallest child ADDs
      auto comparer = [](ADD left, ADD right) {
        return left.nodeCount() > right.nodeCount();
      };
      std::priority_queue<ADD, vector<ADD>, decltype(comparer)> childDds(comparer); // top is rightmost

      for (JoinNode *child : joinNode->getChildren()) {
        childDds.push(countSubtree(child, cnf, projectedCnfVars));
      }

      if (childDds.empty()) showError("no child ADD");
      while (childDds.size() > 1) {
        ADD dd1 = childDds.top();
        childDds.pop();

        ADD dd2 = childDds.top();
        childDds.pop();

        ADD dd3 = dd1 * dd2;
        childDds.push(dd3);
      }
      dd = childDds.top();
    }
    else { // arbitrarily multiplies child ADDs
      for (JoinNode *child : joinNode->getChildren()) {
        dd *= countSubtree(child, cnf, projectedCnfVars);
      }
    }

    for (Int cnfVar : joinNode->getProjectableCnfVars()) {
      projectedCnfVars.insert(cnfVar);

      Int ddVar = cnfVarToDdVarMap.at(cnfVar);
      abstract(dd, ddVar, cnf.getLiteralWeights(), cnf.getWeightFormat());
    }
    return dd;
  }
}

Float Counter::countJoinTree(Cnf &cnf) {
  Int i = cnf.getEmptyClauseIndex();
  if (i != DUMMY_MIN_INT) { // empty clause found
    showWarning("clause " + to_string(i + 1) + " of cnf is empty (1-indexing)");
    return 0;
  }
  else {
    orderDdVars(cnf);

    Set<Int> projectedCnfVars;
    ADD dd = countSubtree(static_cast<JoinNode *>(joinRoot), cnf, projectedCnfVars);

    Float modelCount = diagram::countConstDdFloat(dd);
    modelCount = util::adjustModelCount(modelCount, projectedCnfVars,
                                        cnf.getLiteralWeights(),
                                        cnf.getWeightFormat());
    return modelCount;
  }
}

Float Counter::getModelCount(Cnf &cnf) {
  Int i = cnf.getEmptyClauseIndex();
  if (i != DUMMY_MIN_INT) { // empty clause found
    showWarning("clause " + to_string(i + 1) + " of cnf is empty (1-indexing)");
    return 0;
  }
  else {
    return computeModelCount(cnf);
  }
}

void Counter::output(Cnf &cnf, OutputFormat outputFormat) {
  printComment("Computing output...", 1);

  signal(SIGINT, handleSignals); // Ctrl c
  signal(SIGTERM, handleSignals); // timeout

  switch (outputFormat) {
    case OutputFormat::JOIN_TREE: {
      setJoinTree(cnf);
      printThinLine();
      printJoinTree(cnf);
      printThinLine();
      break;
    }
    case OutputFormat::MODEL_COUNT: {
      util::printSolutionLine(getModelCount(cnf));
      break;
    }
    default: {
      showError("illegal outputFormat " + util::getOutputFormatName(outputFormat) + " -- Counter::ouput");
    }
  }
}

/* class JoinTreeCounter ******************************************************/

void JoinTreeCounter::constructJoinTree(const Cnf &cnf) {}

Float JoinTreeCounter::computeModelCount(Cnf &cnf) {
  bool testing = false;
  // testing = true;
  if (testing) {
    printJoinTree(cnf);
  }

  return countJoinTree(cnf);
}

JoinTreeCounter::JoinTreeCounter(
  Cudd *mgr,
  JoinNonterminal *joinRoot,
  VarOrderingHeuristic ddVarOrderingHeuristic,
  bool inverseDdVarOrdering
) {
  this->mgr = mgr;
  this->joinRoot = joinRoot;
  this->cnfVarOrderingHeuristic = ddVarOrderingHeuristic;
  this->inverseCnfVarOrdering = inverseDdVarOrdering;
}

/* class MonolithicCounter ****************************************************/

void MonolithicCounter::setMonolithicClauseDds(vector<ADD> &clauseDds, Cnf &cnf) {
  clauseDds.clear();
  for (Constraint *clause : cnf.getClauses()) {
    ADD clauseDd = clause->getDD(mgr, cnfVarToDdVarMap);
    clauseDds.push_back(clauseDd);
  }
}

void MonolithicCounter::setCnfDd(ADD &cnfDd, Cnf &cnf) {
  vector<ADD> clauseDds;
  setMonolithicClauseDds(clauseDds, cnf);
  cnfDd = mgr->addOne();
  for (const ADD &clauseDd : clauseDds) {
    cnfDd &= clauseDd; // operator& is operator* in class ADD
  }
}

void MonolithicCounter::constructJoinTree(const Cnf &cnf) {
  vector<JoinNode *> terminals;
  for (size_t clauseIndex = 0; clauseIndex < cnf.getClauses().size();
       clauseIndex++) {
    terminals.push_back(new JoinTerminal());
  }

  vector<Int> projectableCnfVars = cnf.getApparentVars();

  joinRoot = new JoinNonterminal(terminals, Set<Int>(projectableCnfVars.begin(), projectableCnfVars.end()));
}

Float MonolithicCounter::computeModelCount(Cnf &cnf) {
  orderDdVars(cnf);

  ADD cnfDd;
  setCnfDd(cnfDd, cnf);

  Set<Int> support = util::getSupport(cnfDd);
  for (Int ddVar : support) {
    abstract(cnfDd, ddVar, cnf.getLiteralWeights(), cnf.getWeightFormat());
  }

  Float modelCount = diagram::countConstDdFloat(cnfDd);
  modelCount = util::adjustModelCount(modelCount, getCnfVars(support),
                                      cnf.getLiteralWeights(),
                                      cnf.getWeightFormat());
  return modelCount;
}

MonolithicCounter::MonolithicCounter(Cudd *mgr) {
  this->mgr = mgr;
}

/* class FactoredCounter ******************************************************/

/* class LinearCounter ******************************************************/

void LinearCounter::fillProjectableCnfVarSets(
    const vector<Constraint*> &clauses) {
  projectableCnfVarSets = vector<Set<Int>>(clauses.size(), Set<Int>());

  Set<Int> placedCnfVars; // cumulates vars placed in projectableCnfVarSets so far
  for (Int clauseIndex = clauses.size() - 1; clauseIndex >= 0; clauseIndex--) {
    Set<Int> clauseCnfVars = getClauseCnfVars(clauses, clauseIndex);

    Set<Int> placingCnfVars;
    util::differ(placingCnfVars, clauseCnfVars, placedCnfVars);
    projectableCnfVarSets[clauseIndex] = placingCnfVars;
    util::unionize(placedCnfVars, placingCnfVars);
  }
}

void LinearCounter::setLinearClauseDds(vector<ADD> &clauseDds, Cnf &cnf) {
  clauseDds.clear();
  clauseDds.push_back(mgr->addOne());
  for (Constraint *clause : cnf.getClauses()) {
    ADD clauseDd = clause->getDD(mgr, cnfVarToDdVarMap);
    clauseDds.push_back(clauseDd);
  }
}

void LinearCounter::constructJoinTree(const Cnf &cnf) {
  const vector<Constraint*> &clauses = cnf.getClauses();
  fillProjectableCnfVarSets(clauses);

  vector<JoinNode *> clauseNodes;
  for (size_t clauseIndex = 0; clauseIndex < clauses.size(); clauseIndex++) {
    clauseNodes.push_back(new JoinTerminal());
  }

  joinRoot = new JoinNonterminal({clauseNodes.at(0)}, projectableCnfVarSets.at(0));

  for (size_t clauseIndex = 1; clauseIndex < clauses.size(); clauseIndex++) {
    joinRoot = new JoinNonterminal({joinRoot, clauseNodes.at(clauseIndex)}, projectableCnfVarSets.at(clauseIndex));
  }
}

Float LinearCounter::computeModelCount(Cnf &cnf) {
  orderDdVars(cnf);

  vector<ADD> factorDds;
  setLinearClauseDds(factorDds, cnf);
  Set<Int> projectedCnfVars;
  while (factorDds.size() > 1) {
    ADD factor1, factor2;
    util::popBack(factor1, factorDds);
    util::popBack(factor2, factorDds);

    ADD product = factor1 * factor2;
    Set<Int> productDdVars = util::getSupport(product);

    Set<Int> otherDdVars = util::getSupportSuperset(factorDds);

    Set<Int> projectingDdVars;
    util::differ(projectingDdVars, productDdVars, otherDdVars);
    abstractCube(product, projectingDdVars, cnf.getLiteralWeights(),
                 cnf.getWeightFormat());
    util::unionize(projectedCnfVars, getCnfVars(projectingDdVars));

    factorDds.push_back(product);
  }

  Float modelCount = diagram::countConstDdFloat(util::getSoleMember(factorDds));
  modelCount = util::adjustModelCount(modelCount, projectedCnfVars,
                                      cnf.getLiteralWeights(),
                                      cnf.getWeightFormat());
  return modelCount;
}

LinearCounter::LinearCounter(Cudd *mgr) {
  this->mgr = mgr;
}

/* class NonlinearCounter ********************************************************/

void NonlinearCounter::printClusters(const vector<Constraint*> &clauses) const {
  printThinLine();
  printComment("clusters {");
  for (size_t clusterIndex = 0; clusterIndex < clusters.size();
       clusterIndex++) {
    printComment("\t" "cluster " + to_string(clusterIndex + 1) + ":");
    for (Int clauseIndex : clusters.at(clusterIndex)) {
      cout << "c\t\t" "clause " << clauseIndex + 1 << + ":\t";
        clauses.at(clauseIndex)->print();
    }
  }
  printComment("}");
  printThinLine();
}

void NonlinearCounter::fillClusters(const vector<Constraint*> &clauses,
                                    const vector<Int> &cnfVarOrdering,
                                    bool usingMinVar) {
  clusters = vector<vector<Int>>(cnfVarOrdering.size(), vector<Int>());
  for (size_t clauseIndex = 0; clauseIndex < clauses.size(); clauseIndex++) {
    Int clusterIndex = usingMinVar ? clauses.at(clauseIndex)->getMinRank(cnfVarOrdering) : clauses.at(clauseIndex)->getMaxRank(cnfVarOrdering);
    clusters.at(clusterIndex).push_back(clauseIndex);
  }
}

void NonlinearCounter::printOccurrentCnfVarSets() const {
  printComment("occurrentCnfVarSets {");
  for (size_t clusterIndex = 0; clusterIndex < clusters.size();
       clusterIndex++) {
    const Set<Int> &cnfVarSet = occurrentCnfVarSets.at(clusterIndex);
    cout << "c\t" << "cluster " << clusterIndex + 1 << ":";
    for (Int cnfVar : cnfVarSet) {
      cout << " " << cnfVar;
    }
    cout << "\n";
  }
  printComment("}");
}

void NonlinearCounter::printProjectableCnfVarSets() const {
  printComment("projectableCnfVarSets {");
  for (size_t clusterIndex = 0; clusterIndex < clusters.size();
       clusterIndex++) {
    const Set<Int> &cnfVarSet = projectableCnfVarSets.at(clusterIndex);
    cout << "c\t" << "cluster " << clusterIndex + 1 << ":";
    for (Int cnfVar : cnfVarSet) {
      cout << " " << cnfVar;
    }
    cout << "\n";
  }
  cout << "}\n";
  printComment("}");
}

void NonlinearCounter::fillCnfVarSets(
    const vector<Constraint*> &clauses,
    bool usingMinVar) {
  occurrentCnfVarSets = vector<Set<Int>>(clusters.size(), Set<Int>());
  projectableCnfVarSets = vector<Set<Int>>(clusters.size(), Set<Int>());

  Set<Int> placedCnfVars; // cumulates vars placed in projectableCnfVarSets so far
  for (Int clusterIndex = clusters.size() - 1; clusterIndex >= 0; clusterIndex--) {
    Set<Int> clusterCnfVars = getClusterCnfVars(clusters.at(clusterIndex),
                                                clauses);

    occurrentCnfVarSets[clusterIndex] = clusterCnfVars;

    Set<Int> placingCnfVars;
    util::differ(placingCnfVars, clusterCnfVars, placedCnfVars);
    projectableCnfVarSets[clusterIndex] = placingCnfVars;
    util::unionize(placedCnfVars, placingCnfVars);
  }
}

Set<Int> NonlinearCounter::getProjectingDdVars(
    Int clusterIndex, bool usingMinVar, const vector<Int> &cnfVarOrdering,
    const vector<Constraint*> &clauses) {
  Set<Int> projectableCnfVars;

  if (usingMinVar) { // bucket elimination
    projectableCnfVars.insert(cnfVarOrdering.at(clusterIndex));
  }
  else { // Bouquet's Method
    Set<Int> activeCnfVars = getClusterCnfVars(clusters.at(clusterIndex),
                                               clauses);

    Set<Int> otherCnfVars;
    for (size_t i = clusterIndex + 1; i < clusters.size(); i++) {
      util::unionize(otherCnfVars, getClusterCnfVars(clusters.at(i),
                                                     clauses));
    }

    util::differ(projectableCnfVars, activeCnfVars, otherCnfVars);
  }

  Set<Int> projectingDdVars;
  for (Int cnfVar : projectableCnfVars) {
    projectingDdVars.insert(cnfVarToDdVarMap.at(cnfVar));
  }
  return projectingDdVars;
}

void NonlinearCounter::fillDdClusters(
    const vector<Constraint*> &clauses,
    const vector<Int> &cnfVarOrdering, bool usingMinVar) {
  fillClusters(clauses, cnfVarOrdering, usingMinVar);
  if (verbosityLevel >= 2) printClusters(clauses);

  ddClusters = vector<vector<ADD>>(clusters.size(), vector<ADD>());
  for (size_t clusterIndex = 0; clusterIndex < clusters.size();
       clusterIndex++) {
    for (Int clauseIndex : clusters.at(clusterIndex)) {
      ADD clauseDd = clauses.at(clauseIndex)->getDD(mgr, cnfVarToDdVarMap);
      ddClusters.at(clusterIndex).push_back(clauseDd);
    }
  }
}

void NonlinearCounter::fillProjectingDdVarSets(
  const vector<Constraint*> &clauses,
  const vector<Int> &cnfVarOrdering, bool usingMinVar) {
  fillDdClusters(clauses, cnfVarOrdering, usingMinVar);

  projectingDdVarSets = vector<Set<Int>>(clusters.size(), Set<Int>());
  for (size_t clusterIndex = 0; clusterIndex < ddClusters.size();
       clusterIndex++) {
    projectingDdVarSets[clusterIndex] = getProjectingDdVars(clusterIndex,
                                                            usingMinVar,
                                                            cnfVarOrdering,
                                                            clauses);
  }
}

Int NonlinearCounter::getTargetClusterIndex(Int clusterIndex) const {
  const Set<Int> &remainingCnfVars = occurrentCnfVarSets.at(clusterIndex);
  for (size_t i = clusterIndex + 1; i < clusters.size(); i++) {
    if (!util::isDisjoint(occurrentCnfVarSets.at(i), remainingCnfVars)) {
      return i;
    }
  }
  return DUMMY_MAX_INT;
}

Int NonlinearCounter::getNewClusterIndex(const ADD &abstractedClusterDd, const vector<Int> &cnfVarOrdering, bool usingMinVar) const {
  if (usingMinVar) {
    return util::getMinDdRank(abstractedClusterDd, ddVarToCnfVarMap, cnfVarOrdering);
  }
  else {
    const Set<Int> &remainingDdVars = util::getSupport(abstractedClusterDd);
    for (size_t clusterIndex = 0; clusterIndex < clusters.size();
         clusterIndex++) {
      if (!util::isDisjoint(projectingDdVarSets.at(clusterIndex), remainingDdVars)) {
        return clusterIndex;
      }
    }
    return DUMMY_MAX_INT;
  }
}
Int NonlinearCounter::getNewClusterIndex(const Set<Int> &remainingDdVars) const { // #MAVC
  for (size_t clusterIndex = 0; clusterIndex < clusters.size();
       clusterIndex++) {
    if (!util::isDisjoint(projectingDdVarSets.at(clusterIndex), remainingDdVars)) {
      return clusterIndex;
    }
  }
  return DUMMY_MAX_INT;
}

void NonlinearCounter::constructJoinTreeUsingListClustering(const Cnf &cnf, bool usingMinVar) {
  vector<Int> cnfVarOrdering = cnf.getVarOrdering();
  const vector<Constraint*> &clauses = cnf.getClauses();

  fillClusters(clauses, cnfVarOrdering, usingMinVar);
  if (verbosityLevel >= 2) printClusters(clauses);

  fillCnfVarSets(clauses, usingMinVar);
  if (verbosityLevel >= 2) {
    printOccurrentCnfVarSets();
    printProjectableCnfVarSets();
  }

  vector<JoinNode *> terminals;
  for (size_t clauseIndex = 0; clauseIndex < clauses.size(); clauseIndex++) {
    terminals.push_back(new JoinTerminal());
  }

  /* creates cluster nodes: */
  vector<JoinNonterminal *> clusterNodes(clusters.size(), nullptr); // null node for empty cluster
  for (size_t clusterIndex = 0; clusterIndex < clusters.size();
       clusterIndex++) {
    const vector<Int> &clauseIndices = clusters.at(clusterIndex);
    if (!clauseIndices.empty()) {
      vector<JoinNode *> children;
      for (Int clauseIndex : clauseIndices) {
        children.push_back(terminals.at(clauseIndex));
      }
      clusterNodes.at(clusterIndex) = new JoinNonterminal(children);
    }
  }

  Int nonNullClusterNodeIndex = 0;
  while (clusterNodes.at(nonNullClusterNodeIndex) == nullptr) {
    nonNullClusterNodeIndex++;
  }
  JoinNonterminal *nonterminal = clusterNodes.at(nonNullClusterNodeIndex);
  nonterminal->addProjectableCnfVars(projectableCnfVarSets.at(nonNullClusterNodeIndex));
  joinRoot = nonterminal;

  for (size_t clusterIndex = nonNullClusterNodeIndex + 1;
       clusterIndex < clusters.size(); clusterIndex++) {
    JoinNonterminal *clusterNode = clusterNodes.at(clusterIndex);
    if (clusterNode != nullptr) {
      joinRoot = new JoinNonterminal({joinRoot, clusterNode}, projectableCnfVarSets.at(clusterIndex));
    }
  }
}

void NonlinearCounter::constructJoinTreeUsingTreeClustering(const Cnf &cnf, bool usingMinVar) {
  vector<Int> cnfVarOrdering = cnf.getVarOrdering();
  const vector<Constraint*> &clauses = cnf.getClauses();

  fillClusters(clauses, cnfVarOrdering, usingMinVar);
  if (verbosityLevel >= 2) printClusters(clauses);

  fillCnfVarSets(clauses, usingMinVar);
  if (verbosityLevel >= 2) {
    printOccurrentCnfVarSets();
    printProjectableCnfVarSets();
  }

  vector<JoinNode *> terminals;
  for (size_t clauseIndex = 0; clauseIndex < clauses.size(); clauseIndex++) {
    terminals.push_back(new JoinTerminal());
  }

  Int clusterCount = clusters.size();
  joinNodeSets = vector<vector<JoinNode *>>(clusterCount, vector<JoinNode *>()); // clusterIndex -> non-null nodes

  /* creates cluster nodes: */
  for (Int clusterIndex = 0; clusterIndex < clusterCount; clusterIndex++) {
    const vector<Int> &clauseIndices = clusters.at(clusterIndex);
    if (!clauseIndices.empty()) {
      vector<JoinNode *> children;
      for (Int clauseIndex : clauseIndices) {
        children.push_back(terminals.at(clauseIndex));
      }
      joinNodeSets.at(clusterIndex).push_back(new JoinNonterminal(children));
    }
  }

  vector<JoinNode *> rootChildren;
  for (Int clusterIndex = 0; clusterIndex < clusterCount; clusterIndex++) {
    if (joinNodeSets.at(clusterIndex).empty()) continue;

    Set<Int> projectableCnfVars = projectableCnfVarSets.at(clusterIndex);

    Set<Int> remainingCnfVars;
    util::differ(remainingCnfVars, occurrentCnfVarSets.at(clusterIndex), projectableCnfVars);
    occurrentCnfVarSets[clusterIndex] = remainingCnfVars;

    Int targetClusterIndex = getTargetClusterIndex(clusterIndex);
    if (targetClusterIndex <= clusterIndex) {
      showError("targetClusterIndex == " + to_string(targetClusterIndex) + " <= clusterIndex == " + to_string(clusterIndex));
    }
    else if (targetClusterIndex < clusterCount) { // some var remains
      util::unionize(occurrentCnfVarSets.at(targetClusterIndex), remainingCnfVars);

      JoinNonterminal *nonterminal = new JoinNonterminal(joinNodeSets.at(clusterIndex), projectableCnfVars);
      joinNodeSets.at(targetClusterIndex).push_back(nonterminal);
    }
    else if (targetClusterIndex < DUMMY_MAX_INT) {
      showError("clusterCount <= targetClusterIndex < DUMMY_MAX_INT");
    }
    else { // no var remains
      JoinNonterminal *nonterminal = new JoinNonterminal(joinNodeSets.at(clusterIndex), projectableCnfVars);
      rootChildren.push_back(nonterminal);
    }
  }
  joinRoot = new JoinNonterminal(rootChildren);
}

Float NonlinearCounter::countUsingListClustering(Cnf &cnf, bool usingMinVar) {
  orderDdVars(cnf);

  vector<Int> cnfVarOrdering = cnf.getVarOrdering();
  const vector<Constraint*> &clauses = cnf.getClauses();

  fillClusters(clauses, cnfVarOrdering, usingMinVar);
  if (verbosityLevel >= 2) printClusters(clauses);

  /* builds ADD for CNF: */
  ADD cnfDd = mgr->addOne();
  Set<Int> projectedCnfVars;
  for (size_t clusterIndex = 0; clusterIndex < clusters.size();
       clusterIndex++) {
    /* builds ADD for cluster: */
    ADD clusterDd = mgr->addOne();
    const vector<Int> &clauseIndices = clusters.at(clusterIndex);
    for (Int clauseIndex : clauseIndices) {
      ADD clauseDd = clauses.at(clauseIndex)->getDD(mgr, cnfVarToDdVarMap);
      clusterDd *= clauseDd;
    }

    cnfDd *= clusterDd;

    Set<Int> projectingDdVars = getProjectingDdVars(clusterIndex, usingMinVar,
                                                    cnfVarOrdering, clauses);
    abstractCube(cnfDd, projectingDdVars, cnf.getLiteralWeights(),
                 cnf.getWeightFormat());
    util::unionize(projectedCnfVars, getCnfVars(projectingDdVars));
  }

  Float modelCount = diagram::countConstDdFloat(cnfDd);
  modelCount = util::adjustModelCount(modelCount, cnfVarOrdering,
                                      cnf.getLiteralWeights(),
                                      cnf.getWeightFormat());
  return modelCount;
}

Float NonlinearCounter::countUsingTreeClustering(Cnf &cnf, bool usingMinVar) {
  orderDdVars(cnf);

  vector<Int> cnfVarOrdering = cnf.getVarOrdering();
  const vector<Constraint*> &clauses = cnf.getClauses();

  fillProjectingDdVarSets(clauses, cnfVarOrdering, usingMinVar);

  /* builds ADD for CNF: */
  ADD cnfDd = mgr->addOne();
  Set<Int> projectedCnfVars;
  Int clusterCount = clusters.size();
  for (Int clusterIndex = 0; clusterIndex < clusterCount; clusterIndex++) {
    const vector<ADD> &ddCluster = ddClusters.at(clusterIndex);
    if (!ddCluster.empty()) {
      /* builds ADD for cluster: */
      ADD clusterDd = mgr->addOne();
      for (const ADD &dd : ddCluster) clusterDd *= dd;

      Set<Int> projectingDdVars = projectingDdVarSets.at(clusterIndex);
      if (usingMinVar && projectingDdVars.size() != 1) showError("wrong number of projecting vars (bucket elimination)");

      abstractCube(clusterDd, projectingDdVars, cnf.getLiteralWeights(),
                   cnf.getWeightFormat());
      util::unionize(projectedCnfVars, getCnfVars(projectingDdVars));

      Int newClusterIndex = getNewClusterIndex(clusterDd, cnfVarOrdering, usingMinVar);

      if (newClusterIndex <= clusterIndex) {
        showError("newClusterIndex == " + to_string(newClusterIndex) + " <= clusterIndex == " + to_string(clusterIndex));
      }
      else if (newClusterIndex < clusterCount) { // some var remains
        ddClusters.at(newClusterIndex).push_back(clusterDd);
      }
      else if (newClusterIndex < DUMMY_MAX_INT) {
        showError("clusterCount <= newClusterIndex < DUMMY_MAX_INT");
      }
      else { // no var remains
        cnfDd *= clusterDd;
      }
    }
  }

  Float modelCount = diagram::countConstDdFloat(cnfDd);
  modelCount = util::adjustModelCount(modelCount, projectedCnfVars,
                                      cnf.getLiteralWeights(),
                                      cnf.getWeightFormat());
  return modelCount;
}
Float NonlinearCounter::countUsingTreeClustering(Cnf &cnf) { // #MAVC
  orderDdVars(cnf);

  vector<Int> cnfVarOrdering = cnf.getVarOrdering();
  const vector<Constraint*> &clauses = cnf.getClauses();

  bool usingMinVar = false;

  fillProjectingDdVarSets(clauses, cnfVarOrdering, usingMinVar);

  vector<Set<Int>> clustersDdVars; // clusterIndex |-> ddVars
  for (const auto &ddCluster : ddClusters) {
    clustersDdVars.push_back(util::getSupportSuperset(ddCluster));
  }

  Set<Int> cnfDdVars;
  size_t maxDdVarCount = 0;
  Int clusterCount = clusters.size();
  for (Int clusterIndex = 0; clusterIndex < clusterCount; clusterIndex++) {
    const vector<ADD> &ddCluster = ddClusters.at(clusterIndex);
    if (!ddCluster.empty()) {
      Set<Int> clusterDdVars = clustersDdVars.at(clusterIndex);

      maxDdVarCount = std::max(maxDdVarCount, clusterDdVars.size());

      Set<Int> projectingDdVars = projectingDdVarSets.at(clusterIndex);

      Set<Int> remainingDdVars;
      util::differ(remainingDdVars, clusterDdVars, projectingDdVars);

      Int newClusterIndex = getNewClusterIndex(remainingDdVars);

      if (newClusterIndex <= clusterIndex) {
        showError("newClusterIndex == " + to_string(newClusterIndex) + " <= clusterIndex == " + to_string(clusterIndex));
      }
      else if (newClusterIndex < clusterCount) { // some var remains
        util::unionize(clustersDdVars.at(newClusterIndex), remainingDdVars);
      }
      else if (newClusterIndex < DUMMY_MAX_INT) {
        showError("clusterCount <= newClusterIndex < DUMMY_MAX_INT");
      }
      else { // no var remains
        util::unionize(cnfDdVars, remainingDdVars);
        maxDdVarCount = std::max(maxDdVarCount, cnfDdVars.size());
      }
    }
  }

  diagram::printMaxDdVarCount(maxDdVarCount);
  showWarning("NEGATIVE_INFINITY");
  return NEGATIVE_INFINITY;
}

/* class BucketCounter ********************************************************/

void BucketCounter::constructJoinTree(const Cnf &cnf) {
  bool usingMinVar = true;
  return usingTreeClustering ? NonlinearCounter::constructJoinTreeUsingTreeClustering(cnf, usingMinVar) : NonlinearCounter::constructJoinTreeUsingListClustering(cnf, usingMinVar);
}

Float BucketCounter::computeModelCount(Cnf &cnf) {
  bool usingMinVar = true;
  return usingTreeClustering ? NonlinearCounter::countUsingTreeClustering(cnf, usingMinVar) : NonlinearCounter::countUsingListClustering(cnf, usingMinVar);
}

BucketCounter::BucketCounter(Cudd *mgr, bool usingTreeClustering,
                             VarOrderingHeuristic cnfVarOrderingHeuristic,
                             bool inverseCnfVarOrdering) {
  this->mgr = mgr;
  this->usingTreeClustering = usingTreeClustering;
  this->cnfVarOrderingHeuristic = cnfVarOrderingHeuristic;
  this->inverseCnfVarOrdering = inverseCnfVarOrdering;
}

/* class BouquetCounter *******************************************************/

void BouquetCounter::constructJoinTree(const Cnf &cnf) {
  bool usingMinVar = false;
  return usingTreeClustering ? NonlinearCounter::constructJoinTreeUsingTreeClustering(cnf, usingMinVar) : NonlinearCounter::constructJoinTreeUsingListClustering(cnf, usingMinVar);
}

Float BouquetCounter::computeModelCount(Cnf &cnf) {
  bool usingMinVar = false;
  // return NonlinearCounter::countUsingTreeClustering(cnf); // #MAVC
  return usingTreeClustering ? NonlinearCounter::countUsingTreeClustering(cnf, usingMinVar) : NonlinearCounter::countUsingListClustering(cnf, usingMinVar);
}

BouquetCounter::BouquetCounter(Cudd *mgr, bool usingTreeClustering,
                               VarOrderingHeuristic cnfVarOrderingHeuristic,
                               bool inverseCnfVarOrdering) {
  this->mgr = mgr;
  this->usingTreeClustering = usingTreeClustering;
  this->cnfVarOrderingHeuristic = cnfVarOrderingHeuristic;
  this->inverseCnfVarOrdering = inverseCnfVarOrdering;
}

Set<Int> getClusterCnfVars(const vector<Int> &cluster,
                           const vector<Constraint *> &clauses) {
  Set<Int> cnfVars;
  for (Int clauseIndex : cluster)
    util::unionize(cnfVars,
                   getClauseCnfVars(clauses, clauseIndex));
  return cnfVars;
}