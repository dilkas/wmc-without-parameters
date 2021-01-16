#include "../interface/constraint.hpp"

bool Constraint::appearsIn(Int variable) const {
    auto variables = getVariables();
    return find(variables.begin(), variables.end(), variable) !=
           variables.end();
}

Int Constraint::getMinRank(const vector<Int> &cnfVarOrdering) const {
    Int minRank = DUMMY_MAX_INT;
    for (Int variable : getVariables()) {
        Int rank = util::getVariableRank(variable, cnfVarOrdering);
        if (rank < minRank)
            minRank = rank;
    }
    return minRank;
}
Int Constraint::getMaxRank(const vector<Int> &cnfVarOrdering) const {
    Int maxRank = DUMMY_MIN_INT;
    for (Int variable : getVariables()) {
        Int rank = util::getVariableRank(variable, cnfVarOrdering);
        if (rank > maxRank)
            maxRank = rank;
    }
    return maxRank;
}

ADD ClauseConstraint::getDD(Cudd *mgr, Map<Int, Int> &cnfVarToDdVarMap) const {
  ADD clauseDd = mgr->addZero();
  for (Int literal : literals) {
    Int ddVar = cnfVarToDdVarMap.at(util::getCnfVar(literal));
    ADD literalDd = mgr->addVar(ddVar);
    if (!util::isPositiveLiteral(literal)) literalDd = ~literalDd;
    clauseDd |= literalDd;
  }
  return clauseDd;
}

vector<Int> ClauseConstraint::getVariables() const {
    vector<Int> variables;
    for (auto literal : literals)
        variables.push_back(util::getCnfVar(literal));
    return variables;
}

void ClauseConstraint::print() const {
  for (Int literal : literals) {
    cout << std::right << std::setw(5) << literal << " ";
  }
  cout << "\n";
}

bool ClauseConstraint::empty() const {
    return literals.empty();
}

ClauseConstraint::ClauseConstraint(const vector<string> &words,
                                   Int declaredVarCount, Int lineIndex) {
    Int wordCount = words.size();
    for (Int i = 0; i < wordCount; i++) {
        Int num = stoll(words.at(i));

        if (num > declaredVarCount || num < -declaredVarCount)
            util::showError("literal '" + to_string(num) +
                            "' is inconsistent with declared var count '" +
                            to_string(declaredVarCount) + "' -- line " +
                            to_string(lineIndex));

        if (num == 0) {
            if (i != wordCount - 1)
                util::showError(
                    "clause terminated prematurely by '0' -- line " +
                    to_string(lineIndex));
            return;
        } else { // literal
            if (i == wordCount - 1)
                util::showError("missing end-of-clause indicator '" +
                                to_string(0) + "' -- line " +
                                to_string(lineIndex));
            literals.push_back(num);
        }
    }
}

ClauseConstraint::ClauseConstraint(const vector<Int> &literals) {
    this->literals = literals;
}

ADD WeightConstraint::getDD(Cudd *mgr, Map<Int, Int> &cnfVarToDdVarMap) const {
  ADD clauseDd = mgr->addOne();
  for (Int literal : literals) {
    Int ddVar = cnfVarToDdVarMap.at(util::getCnfVar(literal));
    ADD literalDd = mgr->addVar(ddVar);
    if (!util::isPositiveLiteral(literal)) literalDd = ~literalDd;
    clauseDd &= literalDd;
  }
  return mgr->constant((weight - 1)) * clauseDd + mgr->constant(1);
}

void WeightConstraint::print() const {
    cout << "w";
    for (Int literal : literals)
        cout << " " << std::right << std::setw(5) << literal;
    cout << std::right << std::setw(5) << weight << "\n";
}

WeightConstraint::WeightConstraint(const vector<string> &words,
                                   Int declaredVarCount, Int lineIndex)
    : ClauseConstraint(toClauseForm(words), declaredVarCount, lineIndex) {
    weight = std::stod(words.back());
}

vector<string> toClauseForm(const vector<string> &words) {
    vector<string> new_words(words);
    new_words.erase(new_words.begin());
    new_words[new_words.size() - 1] = "0";
    return new_words;
}

void PBConstraint::addTerm(int coefficient, int variable) {
    coefficients.push_back(coefficient);
    variables.push_back(variable);
}

void PBConstraint::setEquality(bool equality) {
    this->equality = equality;
}

void PBConstraint::setDegree(int degree) {
    this->degree = degree;
}

ADD PBConstraint::getDD(Cudd *mgr, Map<Int, Int> &cnfVarToDdVarMap)
    const {
    return (equality) ? constructEqualityDD(0, degree, mgr, cnfVarToDdVarMap) : constructInequalityDD(0, degree, mgr, cnfVarToDdVarMap);
}

ADD PBConstraint::constructEqualityDD(
    size_t firstIndex, int degree, Cudd *mgr,
    Map<Int, Int> &cnfVarToDdVarMap) const {
    if (firstIndex >= coefficients.size())
        return (degree == 0) ? mgr->addOne() : mgr->addZero();
    ADD x1 = mgr->addVar(cnfVarToDdVarMap[variables[firstIndex]]);
    return (x1 & constructEqualityDD(firstIndex + 1,
                                     degree - coefficients[firstIndex], mgr,
                                     cnfVarToDdVarMap)) |
           (~x1 & constructEqualityDD(firstIndex + 1, degree, mgr,
                                      cnfVarToDdVarMap));
}

ADD PBConstraint::constructInequalityDD(
    size_t firstIndex, int degree, Cudd *mgr,
    Map<Int, Int> &cnfVarToDdVarMap) const {
    return mgr->addZero();
    // TODO: implement
    // TODO: implement the 'early stop' conditions
    // TODO: optimize the computation of sums
}

vector<Int> PBConstraint::getVariables() const {
    return variables;
}

void PBConstraint::print() const {
    for (size_t i = 0; i < coefficients.size(); i++) {
        cout << std::showpos << coefficients[i] << std::noshowpos << " x"
             << variables[i] << " ";
    }
    cout << ((equality) ? "= " : ">= ") << degree << std::endl;
}

bool PBConstraint::empty() const {
    return coefficients.empty();
}

PBConstraint::PBConstraint() {}

PBConstraint::PBConstraint(const vector<Int> &variables) {
    this->variables = variables;
}

Set<Int> getClauseCnfVars(const vector<Constraint *> &clause,
                          const vector<vector<Int>> &dependencies,
                          Int clauseIndex) {
    Set<Int> cnfVars;
    if (clauseIndex < clause.size())
    {
        auto variables = clause.at(clauseIndex)->getVariables();
        copy(variables.begin(), variables.end(),
             inserter(cnfVars, cnfVars.end()));
    } else {
    for (Int dependency : dependencies[clauseIndex - clause.size()])
      cnfVars.insert(dependency);
  }
  return cnfVars;
}