#pragma once

#include "util.hpp"

class Constraint {
public:
    virtual ADD getDD(Cudd *mgr, Map<Int, Int> &cnfVarToDdVarMap) const = 0;
    virtual vector<Int> getVariables() const = 0;
    bool appearsIn(Int variable) const;
    Int getMinRank(const vector<Int> &cnfVarOrdering) const;
    Int getMaxRank(const vector<Int> &cnfVarOrdering) const;
    virtual void print() const = 0;
    virtual bool empty() const = 0;
};

class ClauseConstraint : public Constraint {
protected:
    vector<Int> literals;

public:
    ADD getDD(Cudd *mgr, Map<Int, Int> &cnfVarToDdVarMap) const override;
    vector<Int> getVariables() const override;
    void print() const override;
    bool empty() const override;
    ClauseConstraint(const vector<string> &words, Int declaredVarCount,
                     Int lineIndex);
    ClauseConstraint(const vector<Int> &literals);
};

class WeightConstraint : public ClauseConstraint {
private:
    double weight;

public:
    ADD getDD(Cudd *mgr, Map<Int, Int> &cnfVarToDdVarMap) const override;
    void print() const override;
    WeightConstraint(const vector<string> &words, Int declaredVarCount,
                     Int lineIndex);
};

class PBConstraint : public Constraint {
private:
    bool equality; // is the constraint an equality or an inequality?
    Int degree; // the constant on the right-hand-side
    vector<Int> coefficients;
    vector<Int> variables;
    ADD constructEqualityDD(size_t firstIndex, int degree, Cudd *mgr,
                            Map<Int, Int> &cnfVarToDdVarMap) const;
    ADD constructInequalityDD(size_t firstIndex, int degree, Cudd *mgr,
                              Map<Int, Int> &cnfVarToDdVarMap) const;

public:
    void addTerm(int coefficient, int variable);
    void setEquality(bool equality);
    void setDegree(int degree);
    ADD getDD(Cudd *mgr, Map<Int, Int> &cnfVarToDdVarMap) const override;
    vector<Int> getVariables() const override;
    void print() const override;
    bool empty() const override;
    PBConstraint();
    PBConstraint(const vector<Int> &variables);
};

Set<Int> getClauseCnfVars(const vector<Constraint*> &clause,
                          const vector<vector<Int>> &dependencies,
                          Int clause_index);
vector<string> toClauseForm(const vector<string> &words);