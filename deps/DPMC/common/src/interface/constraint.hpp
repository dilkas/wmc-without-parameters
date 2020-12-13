#pragma once

#include <string>
#include <vector>

using std::string;
using std::vector;

class PBConstraint {
private:
    bool equality; // is the constraint an equality or an inequality?
    int degree; // the constant on the right-hand-side
    vector<int> coefficients;
    vector<int> variables;
public:
    void addTerm(int coefficient, int variable);
    void setEquality(bool equality);
    void setDegree(int degree);
    PBConstraint();
};