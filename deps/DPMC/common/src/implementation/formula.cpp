/* inclusions *****************************************************************/

#include "../interface/formula.hpp"

/* constants ******************************************************************/

const string &CNF_WORD = "cnf";
const string &WCNF_WORD = "wcnf";
const string &WEIGHTS_WORD = "weights";
const string &WEIGHT_WORD = "w";
const string &LINE_END_WORD = "0";

const Float CACHET_DEFAULT_VAR_WEIGHT = 0.5;
const Float MCC_DEFAULT_LITERAL_WEIGHT = 1;

/* classes ********************************************************************/

/* class Label ****************************************************************/

void Label::addNumber(Int i) {
  push_back(i);
  std::sort(begin(), end(), std::greater<Int>());
}

/* class Cnf ******************************************************************/

void Cnf::updateApparentVars(Int literal) {
  Int var = util::getCnfVar(literal);
  if (!util::isFound(var, apparentVars)) apparentVars.push_back(var);
}

void Cnf::addClause(Constraint *clause) {
  clauses.push_back(clause);
  for (Int variable : clause->getVariables())
    updateApparentVars(variable);
}

Graph Cnf::getGaifmanGraph() const {
  Set<Int> vars;
  for (Int var : apparentVars) vars.insert(var);
  Graph graph(vars);

  for (Constraint *clause : clauses) {
    auto variables = clause->getVariables();
    for (auto var1 = variables.begin(); var1 != variables.end(); var1++) {
      for (auto var2 = std::next(var1); var2 != variables.end(); var2++) {
        graph.addEdge(*var1, *var2);
      }
    }
  }
  return graph;
}

vector<Int> Cnf::getAppearanceVarOrdering() const {
  return apparentVars;
}

vector<Int> Cnf::getDeclarationVarOrdering() const {
  vector<Int> varOrdering = apparentVars;
  std::sort(varOrdering.begin(), varOrdering.end());
  return varOrdering;
}

vector<Int> Cnf::getRandomVarOrdering() const {
  vector<Int> varOrdering = apparentVars;
  util::shuffleRandomly(varOrdering);
  return varOrdering;
}

vector<Int> Cnf::getMcsVarOrdering() const {
  Graph graph = getGaifmanGraph();

  auto startVertex = graph.beginVertices();
  if (startVertex == graph.endVertices()) // empty graph
    return vector<Int>();

  Map<Int, Int> rankedNeighborCounts; // unranked vertex |-> number of ranked neighbors
  for (auto it = std::next(startVertex); it != graph.endVertices(); it++) rankedNeighborCounts[*it] = 0;

  Int bestVertex = *startVertex;
  Int bestRankedNeighborCount = DUMMY_MIN_INT;

  vector<Int> varOrdering;
  do {
    varOrdering.push_back(bestVertex);

    rankedNeighborCounts.erase(bestVertex);

    for (auto n = graph.beginNeighbors(bestVertex); n != graph.endNeighbors(bestVertex); n++) {
      auto entry = rankedNeighborCounts.find(*n);
      if (entry != rankedNeighborCounts.end()) entry->second++;
    }

    bestRankedNeighborCount = DUMMY_MIN_INT;
    for (const std::pair<Int, Int> &entry : rankedNeighborCounts) {
      if (entry.second > bestRankedNeighborCount) {
        bestRankedNeighborCount = entry.second;
        bestVertex = entry.first;
      }
    }
  }
  while (bestRankedNeighborCount != DUMMY_MIN_INT);

  return varOrdering;
}

vector<Int> Cnf::getLexpVarOrdering() const {
  Map<Int, Label> unnumberedVertices;
  for (Int vertex : apparentVars) unnumberedVertices[vertex] = Label();
  vector<Int> numberedVertices; // whose alpha numbers are decreasing
  Graph graph = getGaifmanGraph();
  for (Int number = apparentVars.size(); number > 0; number--) {
    auto vertexIt = max_element(unnumberedVertices.begin(), unnumberedVertices.end(), util::isLessValued<Int, Label>);
    Int vertex = vertexIt->first; // ignores label
    numberedVertices.push_back(vertex);
    unnumberedVertices.erase(vertex);
    for (auto neighborIt = graph.beginNeighbors(vertex); neighborIt != graph.endNeighbors(vertex); neighborIt++) {
      Int neighbor = *neighborIt;
      auto unnumberedNeighborIt = unnumberedVertices.find(neighbor);
      if (unnumberedNeighborIt != unnumberedVertices.end()) {
        Int unnumberedNeighbor = unnumberedNeighborIt->first;
        unnumberedVertices.at(unnumberedNeighbor).addNumber(number);
      }
    }
  }
  return numberedVertices;
}

vector<Int> Cnf::getLexmVarOrdering() const {
  Map<Int, Label> unnumberedVertices;
  for (Int vertex : apparentVars) unnumberedVertices[vertex] = Label();
  vector<Int> numberedVertices; // whose alpha numbers are decreasing
  Graph graph = getGaifmanGraph();
  for (Int i = apparentVars.size(); i > 0; i--) {
    auto vIt = max_element(unnumberedVertices.begin(), unnumberedVertices.end(), util::isLessValued<Int, Label>);
    Int v = vIt->first; // ignores label
    numberedVertices.push_back(v);
    unnumberedVertices.erase(v);

    /* updates numberedVertices: */
    Graph subgraph = getGaifmanGraph(); // will only contain v, w, and unnumbered vertices whose labels are less than w's
    for (auto wIt = unnumberedVertices.begin(); wIt != unnumberedVertices.end(); wIt++) {
      Int w = wIt->first;
      Label &wLabel = wIt->second;

      /* removes numbered vertices except v: */
      for (Int numberedVertex : numberedVertices)
        if (numberedVertex != v)
          subgraph.removeVertex(numberedVertex);

      /* removes each non-w unnumbered vertex whose label is not less than w's */
      for (const std::pair<Int, Label> &kv : unnumberedVertices) {
        Int unnumberedVertex = kv.first;
        const Label &label = kv.second;
        if (unnumberedVertex != w && label >= wLabel)
          subgraph.removeVertex(unnumberedVertex);
      }

      if (subgraph.hasPath(v, w)) wLabel.addNumber(i);
    }
  }
  return numberedVertices;
}

vector<Int> Cnf::getMinFillVarOrdering() const {
  vector<Int> varOrdering;

  Graph graph = getGaifmanGraph();
  Set<Int> unmarkedVertices(apparentVars.begin(), apparentVars.end());
  while (!unmarkedVertices.empty()) {
    Int vertex = graph.getMinFillVertex(unmarkedVertices);
    graph.fillInEdges(vertex);
    unmarkedVertices.erase(vertex);

    varOrdering.push_back(vertex);
  }

  return varOrdering;
}

vector<Int> Cnf::generateVarOrdering(VarOrderingHeuristic varOrderingHeuristic, bool inverse) const {
  vector<Int> varOrdering;
  switch (varOrderingHeuristic) {
    case VarOrderingHeuristic::APPEARANCE: {
      varOrdering = getAppearanceVarOrdering();
      break;
    }
    case VarOrderingHeuristic::DECLARATION: {
      varOrdering = getDeclarationVarOrdering();
      break;
    }
    case VarOrderingHeuristic::RANDOM: {
      varOrdering = getRandomVarOrdering();
      break;
    }
    case VarOrderingHeuristic::MCS: {
      varOrdering = getMcsVarOrdering();
      break;
    }
    case VarOrderingHeuristic::LEXP: {
      varOrdering = getLexpVarOrdering();
      break;
    }
    case VarOrderingHeuristic::LEXM: {
      varOrdering = getLexmVarOrdering();
      break;
    }
    case VarOrderingHeuristic::MIN_FILL: {
      varOrdering = getMinFillVarOrdering();
      break;
    }
    default: {
      showError("DUMMY_VAR_ORDERING_HEURISTIC -- Cnf::getVarOrdering");
    }
  }
  if (inverse) {
    util::invert(varOrdering);
  }
  return varOrdering;
}

vector<Int> Cnf::getVarOrdering() const {
  return varOrdering;
}

const vector<ADD> &Cnf::getWeights() const {
  return weights;
}

const vector<vector<Int>> &Cnf::getDependencies() const {
  return dependencies;
}

WeightFormat Cnf::getWeightFormat() const {
  return weightFormat;
}

Int Cnf::getDeclaredVarCount() const { return declaredVarCount; }

Map<Int, Float> Cnf::getLiteralWeights() const { return literalWeights; }

Int Cnf::getEmptyClauseIndex() const {
  for (Int clauseIndex = 0; clauseIndex < clauses.size(); clauseIndex++) {
    if (clauses.at(clauseIndex)->empty()) {
      return clauseIndex;
    }
  }
  return DUMMY_MIN_INT;
}

const vector<Constraint*> &Cnf::getClauses() const { return clauses; }

const vector<Int> &Cnf::getApparentVars() const { return apparentVars; }

void Cnf::printLiteralWeights() const {
  util::printLiteralWeights(literalWeights);
}

void Cnf::printClauses() const {
  printComment("cnf {");
  for (Int i = 0; i < clauses.size(); i++) {
    cout << "c\t" "clause ";
    cout << std::right << std::setw(5) << i + 1 << " : ";
    clauses.at(i)->print();
  }
  printComment("}");
}

void Cnf::printWeightedFormula(const WeightFormat &outputWeightFormat) const {
  printComment("Printing weighted formula...", 1);
  printThinLine();

  Int apparentVarCount = apparentVars.size();
  switch (outputWeightFormat) {
    case WeightFormat::MINIC2D: {
      cout << PROBLEM_WORD << " " << CNF_WORD << " " << apparentVarCount << " " << clauses.size() << "\n";

      cout << "c " << WEIGHTS_WORD << " ";
      for (Int var = 1; var <= apparentVarCount; var++) {
        cout << literalWeights.at(var) << " " << literalWeights.at(-var) << " ";
      }
      cout << "\n";

      break;
    }
    case WeightFormat::CACHET: {
      cout << PROBLEM_WORD << " " << CNF_WORD << " " << apparentVarCount << " " << clauses.size() << "\n";

      for (Int var = 1; var <= apparentVarCount; var++) {
        Float positiveWeight = literalWeights.at(var);
        Float negativeWeight = literalWeights.at(-var);
        if (positiveWeight == 1 && negativeWeight == 1) {
          cout << WEIGHT_WORD << " " << var << " " << -1 << "\n";
        }
        else {
          cout << WEIGHT_WORD << " " << var << " " << positiveWeight << "\n";

          if (positiveWeight + negativeWeight != 1) {
            showWarning("var " + to_string(var) + " has negetive literal weight " + to_string(negativeWeight));
          }
        }
      }

      break;
    }
    case WeightFormat::MCC: {
      cout << PROBLEM_WORD << " " << WCNF_WORD << " " << apparentVarCount << " " << clauses.size() << "\n";

      for (Int var = 1; var <= apparentVarCount; var++) {
        cout << WEIGHT_WORD << " " << var << " " << literalWeights.at(var) << " " << LINE_END_WORD << "\n";
        cout << WEIGHT_WORD << " " << -var << " " << literalWeights.at(-var) << " " << LINE_END_WORD << "\n";
      }

      break;
    }
    default: {
      showError("outputWeightFormat " + util::getWeightFormatName(outputWeightFormat) + " unsupported by Cnf::printWeightedFormula");
    }
  }

  for (Constraint *clause : clauses)
    clause->print();

  printThinLine();
}

ADD Cnf::literalToDd(Int literal, Cudd *mgr) {
  auto it = std::find(varOrdering.begin(), varOrdering.end(),
                      std::abs(literal));
  Int index = std::distance(varOrdering.begin(), it);
  return mgr->addVar(index);
}

ADD Cnf::constructDdFromWords(Cudd *mgr, Int var,
                              const vector<std::string> &words) {
  ADD positive = literalToDd(var, mgr);
  ADD negative = ~positive;
  for (Int i = 2; i < words.size() - 2; i++) {
    Int var = std::stoi(words.at(i));
    ADD varADD = literalToDd(var, mgr);
    ADD newVariable = (var > 0) ? varADD : ~varADD;
    positive &= newVariable;
    negative &= newVariable;
  }
  double_t positiveWeight = std::stod(words.at(words.size() - 2));
  double_t negativeWeight = std::stod(words.at(words.size() - 1));
  return (mgr->constant(positiveWeight) * positive) +
         (mgr->constant(negativeWeight) * negative);
}

Cnf::Cnf(const vector<Constraint*> &clauses) {
  this->clauses = clauses;

  for (Constraint *clause : clauses)
    for (Int variable : clause->getVariables())
      updateApparentVars(variable);
}

Cnf::Cnf(const string &filePath, Format format, WeightFormat weightFormat,
         Cudd *mgr, VarOrderingHeuristic varOrderingHeuristic, bool inverse) {
  printComment("Reading CNF formula...", 1);

  std::ifstream inputFileStream(filePath); // variable will be destroyed if it goes out of scope
  std::istream *inputStream;
  if (filePath == STDIN_CONVENTION) {
    inputStream = &std::cin;

    printThickLine();
    printComment("Getting cnf from stdin... (end input with 'Enter' then 'Ctrl d')");
  }
  else {
    if (!inputFileStream.is_open()) {
      showError("unable to open file '" + filePath + "'");
    }
    inputStream = &inputFileStream;
  }

  this->weightFormat = weightFormat;

  Int declaredClauseCount = DUMMY_MIN_INT;
  Int processedClauseCount = 0;

  Int lineIndex = 0;
  Int problemLineIndex = DUMMY_MIN_INT;
  Int minic2dWeightLineIndex = DUMMY_MIN_INT;
  std::stringstream pbInput;

  string line;
  while (std::getline(*inputStream, line)) {
    lineIndex++;
    std::istringstream inputStringStream(line);

    if (verbosityLevel >= 3) printComment("Line " + to_string(lineIndex) + "\t" + line);

    vector<string> words;
    std::copy(std::istream_iterator<string>(inputStringStream), std::istream_iterator<string>(), std::back_inserter(words));

    Int wordCount = words.size();

    if (wordCount < 1) continue;

    const string &startWord = words.at(0);
    if (startWord == PROBLEM_WORD) {
      if (problemLineIndex != DUMMY_MIN_INT) {
        showError("multiple problem lines: " + to_string(problemLineIndex) + " and " + to_string(lineIndex));
      }
      problemLineIndex = lineIndex;

      if (wordCount != 4) {
        showError("problem line " + to_string(lineIndex) + " has " + to_string(wordCount) + " words (should be 4)");
      }

      const string &cnfKey = weightFormat == WeightFormat::MCC ? WCNF_WORD : CNF_WORD;
      const string &cnfWord = words.at(1);
      if (cnfKey != cnfWord) {
        showError("expected '" + cnfKey + "', found '" + cnfWord + "' -- line " + to_string(lineIndex));
      }

      declaredVarCount = std::stoll(words.at(2));
      declaredClauseCount = std::stoll(words.at(3));
    }
    else if (startWord == "c") { // comment
      if (weightFormat == WeightFormat::MINIC2D && wordCount > 1 && words.at(1) == WEIGHTS_WORD) { // MINIC2D weight line
        if (format == Format::CNF && problemLineIndex == DUMMY_MIN_INT) {
          showError("no problem line before MINIC2D weight line " + to_string(lineIndex));
        }
        if (minic2dWeightLineIndex != DUMMY_MIN_INT) {
          showError("multiple MINIC2D weight lines: " + to_string(minic2dWeightLineIndex) + " and " + to_string(lineIndex));
        }
        minic2dWeightLineIndex = lineIndex;

        if (wordCount != 2 + declaredVarCount * 2 && wordCount != 3 + declaredVarCount * 2) {
          showError("wrong number of MINIC2D literal weights -- line " +
                    to_string(lineIndex) + ". Expected " +
                    to_string(2 + declaredVarCount * 2) + " but got " +
                    to_string(wordCount));
        }

        for (Int var = 1; var <= declaredVarCount; var++) {
          literalWeights[var] = std::stold(words.at(var * 2));
          literalWeights[-var] = std::stold(words.at(var * 2 + 1));
        }
        if (wordCount == 3 + declaredVarCount * 2)
          literalWeights[0] = std::stold(words.at(wordCount - 1));
      }
    }
    else if (startWord == WEIGHT_WORD) {
      if (format == Format::CNF && problemLineIndex == DUMMY_MIN_INT) {
        showError("no problem line before weight line " + to_string(lineIndex));
      }

      if (weightFormat == WeightFormat::CACHET && wordCount == 3) {
        Int var = std::stoll(words.at(1));
        if (var <= 0 || var > declaredVarCount) {
          showError("var '" + to_string(var) + "' is inconsistent with declared var count '" + to_string(declaredVarCount) + "' -- line " + to_string(lineIndex));
        }
        Float weight = std::stold(words.at(2));
        literalWeights[var] = weight;
      } else if (weightFormat == WeightFormat::CONDITIONAL) {
        if (words[1] == "0") {
          literalWeights[0] = std::stod(words[2]);
        } else {
          ClauseConstraint *constraint = new WeightConstraint(words,
                                                              declaredVarCount,
                                                              lineIndex);
          addClause(constraint);
          processedClauseCount++;
        }
      } else if (weightFormat == WeightFormat::MCC && (wordCount == 3 || wordCount == 4 && words.at(3) == LINE_END_WORD)) {
        Int literal = std::stoll(words.at(1));

        Int var = util::getCnfVar(literal);
        if (var <= 0 || var > declaredVarCount) {
          showError("literal '" + to_string(literal) + "' is inconsistent with declared var count '" + to_string(declaredVarCount) + "' -- line " + to_string(lineIndex));
        }

        Float weight = std::stold(words.at(2));
        literalWeights[literal] = weight;
      }
      else {
        showError("weight line " + to_string(lineIndex) + " is inconsistent with weight format " + util::getWeightFormatName(weightFormat));
      }
    }
    else { // clause line
      if (format == Format::CNF) {
        if (problemLineIndex == DUMMY_MIN_INT) {
          showError("no problem line before clause line " +
                    to_string(lineIndex));
        }
        ClauseConstraint *constraint = new ClauseConstraint(words,
                                                            declaredVarCount,
                                                            lineIndex);
        addClause(constraint);
        processedClauseCount++;
      } else {
        pbInput << line << endl;
      }
    }
  }

  if (filePath == STDIN_CONVENTION) {
    printComment("Getting cnf from stdin: done");
    printThickLine();
  }

  if (format == Format::CNF && problemLineIndex == DUMMY_MIN_INT) {
    showError("no problem line before cnf file ends on line " + to_string(lineIndex));
  }

  if (format == Format::PB) {
    SimpleParser<DPMCCallback> parser(&pbInput);
    parser.setAutoLinearize(true);
    parser.parse();
    declaredVarCount = parser.cb.declaredVarCount;
    declaredClauseCount = parser.cb.declaredConstraintCount;
    processedClauseCount = parser.cb.constraints.size();
    for (auto constraint : parser.cb.constraints)
      addClause(constraint);
  }

  if (weightFormat == WeightFormat::MINIC2D && minic2dWeightLineIndex == DUMMY_MIN_INT) {
    showError("MINIC2D weight line not found");
  }

  // populates literalWeights with 1s
  if (weightFormat == WeightFormat::UNWEIGHTED ||
      weightFormat == WeightFormat::CONDITIONAL) {
    for (Int var = 1; var <= declaredVarCount; var++) {
      literalWeights[var] = 1;
      literalWeights[-var] = 1;
    }
  }
  else if (weightFormat == WeightFormat::CACHET) { // completes literalWeights
    for (Int var = 1; var <= declaredVarCount; var++) {
      Float varWeight = CACHET_DEFAULT_VAR_WEIGHT;
      if (literalWeights.find(var) != literalWeights.end()) {
        varWeight = literalWeights.at(var);
      }

      Float negativeLiteralWeight = 1 - varWeight;
      if (varWeight == -1) {
        varWeight = negativeLiteralWeight = 1;
      }

      literalWeights[var] = varWeight;
      literalWeights[-var] = negativeLiteralWeight;
    }
  }
  else if (weightFormat == WeightFormat::MCC) { // completes literalWeights
    for (Int var = 1; var <= declaredVarCount; var++) {
      if (literalWeights.find(var) == literalWeights.end()) {
        literalWeights[var] = MCC_DEFAULT_LITERAL_WEIGHT;
      }
      if (literalWeights.find(-var) == literalWeights.end()) {
        literalWeights[-var] = MCC_DEFAULT_LITERAL_WEIGHT;
      }
    }
  }

  varOrdering = generateVarOrdering(varOrderingHeuristic, inverse);

  if (verbosityLevel >= 1) {
    util::printRow("declaredVarCount", declaredVarCount);
    util::printRow("apparentVarCount", apparentVars.size());
    util::printRow("declaredClauseCount", declaredClauseCount);
    util::printRow("apparentClauseCount", processedClauseCount);
  }

  if (verbosityLevel >= 2) {
    printThinLine();
    printClauses();
    printLiteralWeights();
    printThinLine();
  }
}
