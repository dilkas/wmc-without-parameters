#pragma once

#include "util.hpp"

class Constraint {
public:
    virtual ADD getDD(Cudd *mgr, Map<Int, Int> cnfVarToDdVarMap) const = 0;
    virtual vector<Int> getVariables() const = 0;
    bool appearsIn(Int variable) const;
    Int getMinRank(const vector<Int> &cnfVarOrdering) const;
    Int getMaxRank(const vector<Int> &cnfVarOrdering) const;
    virtual void print() const = 0;
    virtual bool empty() const = 0;
};

class ClauseConstraint : public Constraint {
private:
    vector<Int> literals;

public:
    ADD getDD(Cudd *mgr, Map<Int, Int> cnfVarToDdVarMap) const override;
    vector<Int> getVariables() const override;
    void print() const override;
    bool empty() const override;
    ClauseConstraint(vector<string> words, Int declaredVarCount, Int lineIndex);
};

class PBConstraint : public Constraint {
private:
    bool equality; // is the constraint an equality or an inequality?
    Int degree; // the constant on the right-hand-side
    vector<Int> coefficients;
    vector<Int> variables;

public:
    void addTerm(int coefficient, int variable);
    void setEquality(bool equality);
    void setDegree(int degree);
    ADD getDD(Cudd *mgr, Map<Int, Int> cnfVarToDdVarMap) const override;
    vector<Int> getVariables() const override;
    void print() const override;
    bool empty() const override;
    PBConstraint();
};

Set<Int> getClauseCnfVars(const vector<Constraint*> &clause,
                          const vector<vector<Int>> &dependencies,
                          Int clause_index);