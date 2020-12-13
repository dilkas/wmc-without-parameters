#include "../interface/SimpleParser.hpp"

void DefaultCallback::metaData(int nbvar, int nbconstr)
{
  cout << "[nbvar=" << nbvar << "]" << endl;
  cout << "[nbconstr=" << nbconstr << "]" << endl;
}

void DefaultCallback::beginObjective()
{
  cout << "objective:  ";
}

void DefaultCallback::endObjective()
{
  cout << endl;
}

void DefaultCallback::objectiveTerm(IntegerType coeff, int idVar)
{
  cout << "[" << showpos << coeff << noshowpos << " x" << idVar << "] ";
}

void DefaultCallback::objectiveProduct(IntegerType coeff, vector<int> list)
{
  cout << "[" << showpos << coeff << noshowpos << " ";
  for (int i = 0; i < list.size(); ++i)
  {
    if (list[i] < 0)
      cout << "~x" << -list[i] << ' ';
    else
      cout << "x" << list[i] << ' ';
  }
  cout << "] ";
}

void DefaultCallback::beginConstraint()
{
  cout << "constraint: ";
}

void DefaultCallback::endConstraint()
{
  cout << endl;
}

void DefaultCallback::constraintTerm(IntegerType coeff, int idVar)
{
  cout << "[" << showpos << coeff << noshowpos << " x" << idVar << "] ";
}

void DefaultCallback::constraintProduct(IntegerType coeff, vector<int> list)
{
  cout << "[" << showpos << coeff << noshowpos << " ";
  for (int i = 0; i < list.size(); ++i)
  {
    if (list[i] < 0)
      cout << "~x" << -list[i] << ' ';
    else
      cout << "x" << list[i] << ' ';
  }
  cout << "] ";
}

void DefaultCallback::constraintRelOp(string relop)
{
  cout << "[" << relop << "] ";
}

void DefaultCallback::constraintRightTerm(IntegerType val)
{
  cout << "[" << val << "]";
}

void DefaultCallback::linearizeProduct(int newSymbol, vector<int> product)
{
  IntegerType r;

  // product => newSymbol (this is a clause)
  // not x0 or not x1 or ... or not xn or newSymbol
  r = 1;
  beginConstraint();
  constraintTerm(1, newSymbol);
  for (int i = 0; i < product.size(); ++i)
    if (product[i] > 0)
    {
      constraintTerm(-1, product[i]);
      r -= 1;
    }
    else
      constraintTerm(1, -product[i]);
  constraintRelOp(">=");
  constraintRightTerm(r);
  endConstraint();

#ifdef ONLYCLAUSES
  // newSymbol => product translated as
  // not newSymbol of xi (for all i)
  for (int i = 0; i < product.size(); ++i)
  {
    r = 0;
    beginConstraint();
    constraintTerm(-1, newSymbol);
    if (product[i] > 0)
      constraintTerm(1, product[i]);
    else
    {
      constraintTerm(-1, -product[i]);
      r -= 1;
    }
    constraintRelOp(">=");
    constraintRightTerm(r);
    endConstraint();
  }
#else
  // newSymbol => product translated as
  // x0+x1+x3...+xn-n*newSymbol>=0
  r = 0;
  beginConstraint();
  constraintTerm(-(int)product.size(), newSymbol);
  for (int i = 0; i < product.size(); ++i)
    if (product[i] > 0)
      constraintTerm(1, product[i]);
    else
    {
      constraintTerm(-1, -product[i]);
      r -= 1;
    }
  constraintRelOp(">=");
  constraintRightTerm(r);
  endConstraint();
#endif
}

void DPMCCallback::metaData(int nbvar, int nbconstr) {}

void DPMCCallback::beginObjective()
{
  util::showError("objectives are not supported");
}

void DPMCCallback::endObjective()
{
  util::showError("objectives are not supported");
}

void DPMCCallback::objectiveTerm(IntegerType coeff, int idVar)
{
  util::showError("objectives are not supported");
}

void DPMCCallback::objectiveProduct(IntegerType coeff, vector<int> list)
{
  util::showError("objectives are not supported");
}

void DPMCCallback::beginConstraint()
{
  currentConstraint = PBConstraint();
}

void DPMCCallback::endConstraint()
{
  constraints.push_back(currentConstraint);
}

void DPMCCallback::constraintTerm(IntegerType coeff, int idVar)
{
  currentConstraint.addTerm(coeff, idVar);
}

void DPMCCallback::constraintProduct(IntegerType coeff, vector<int> list)
{
  util::showError("product terms must be linearized");
}

void DPMCCallback::constraintRelOp(string relop)
{
  currentConstraint.setEquality(relop == "=");
}

void DPMCCallback::constraintRightTerm(IntegerType val)
{
  currentConstraint.setDegree(val);
}

// int main(int argc, char *argv[])
// {
//   try
//   {
//     if (argc != 2)
//       cout << "usage: SimpleParser <filename>" << endl;
//     else
//     {
//       SimpleParser<DefaultCallback> parser(argv[1]);

//       parser.setAutoLinearize(true);
//       parser.parse();
//     }
//   }
//   catch (exception &e)
//   {
//     cout.flush();
//     cerr << "ERROR: " << e.what() << endl;
//   }

//   return 0;
// }
