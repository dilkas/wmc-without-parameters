#pragma once

#include <string>
#include <vector>

using std::string;
using std::vector;

class PBConstraint {
private:
    bool equality;
    int degree;
    vector<int> coefficients;
    vector<int> variables;
public:
    PBConstraint(string representation);
};