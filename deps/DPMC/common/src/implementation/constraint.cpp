#include "../interface/constraint.hpp"

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

PBConstraint::PBConstraint() {}