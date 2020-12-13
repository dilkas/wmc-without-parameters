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
    Int maxRank = DUMMY_MAX_INT;
    for (Int variable : getVariables()) {
        Int rank = util::getVariableRank(variable, cnfVarOrdering);
        if (rank > maxRank)
            maxRank = rank;
    }
    return maxRank;
}

ADD ClauseConstraint::getDD(Cudd *mgr, Map<Int, Int> cnfVarToDdVarMap) const {
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

ClauseConstraint::ClauseConstraint(vector<string> words,
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

ADD PBConstraint::getDD(Cudd *mgr, Map<Int, Int> cnfVarToDdVarMap) const {
    // TODO: implement
    return mgr->addZero();
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