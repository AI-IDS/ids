//#define _SECURE_SCL 0

#include <iostream>
#include "string.h"
#include "host.h"
#include <map>
#include <fstream>
#include <vector>
#include <sstream>

using namespace std;

class Discretizer {
public:
	// Write line to line, return true on success, otherwise EOF; exit on parsing error
	static bool get_next_line(string &line);

private:
	typedef struct {
		enum { INT, DOUBLE, PRINT, NOPRINT } type;
		char *name;
		int count; // number of bounds
		double *bounds;
		char **labels;
	} discr_t;


	static const double b_bool[];
	static const double b_duration[4];
	static const double b_srcbytes[];
	static const double b_dstbytes[];
	static const double b_count[];
	static const double b_rates[];
	static const double b_dst_count[];

	static const char *l_lh[];
	static const char *l_lmh[];
	static const char *l_llmh[];
	static const char *l_yn[];

	static const discr_t recs[];
	static const int n_recs;

	static void write_column(stringstream &ss, int col_i, char *value);
	static const char *get_label(int col, double value);
};

// To takovyto zlobr
const double Discretizer::b_bool[] = { 0 };
const double Discretizer::b_duration[] = { 0, 100 };
const double Discretizer::b_srcbytes[] = { 7500, 45000 };
const double Discretizer::b_dstbytes[] = { 75000, 300000 };
const double Discretizer::b_count[] = { 117, 510 };
const double Discretizer::b_rates[] = { 0.26, 0.51, 0.76 };
const double Discretizer::b_dst_count[] = { 254 };
const char *Discretizer::l_lh[] = { "low", "high" };
const char *Discretizer::l_lmh[] = { "low", "mid", "high" };
const char *Discretizer::l_llmh[] = { "low", "lowmid", "mid", "high" };
const char *Discretizer::l_yn[] = { "yes", "no" };
const Discretizer::discr_t Discretizer::recs[] = {
	{ Discretizer::discr_t::INT, "duration", 2, (double *)&b_duration, (char **)&l_lmh },
	{ Discretizer::discr_t::PRINT, "protocoltype", 0, nullptr, nullptr },
	{ Discretizer::discr_t::PRINT, "service", 0, nullptr, nullptr },
	{ Discretizer::discr_t::PRINT, "flag", 0, nullptr, nullptr },
	{ Discretizer::discr_t::INT, "srcbytes", 2, (double *)&b_srcbytes, (char **)&l_lmh },
	{ Discretizer::discr_t::INT, "dstbytes", 2, (double *)&b_dstbytes, (char **)&l_lmh },
	{ Discretizer::discr_t::NOPRINT, "land", 1, (double *)&b_bool, (char **)&l_yn },
	{ Discretizer::discr_t::NOPRINT, "wrongfragment", 1, (double *)&b_bool, (char **)&l_yn },
	{ Discretizer::discr_t::NOPRINT, "urgent", 1, (double *)&b_bool, (char **)&l_yn },
	{ Discretizer::discr_t::INT, "count", 2, (double *)&b_count, (char **)&l_lmh },
	{ Discretizer::discr_t::INT, "srvcount", 2, (double *)&b_count, (char **)&l_lmh },
	{ Discretizer::discr_t::DOUBLE, "serrorrate", 3, (double *)&b_rates, (char **)&l_llmh },
	{ Discretizer::discr_t::DOUBLE, "srvserrorrate", 3, (double *)&b_rates, (char **)&l_llmh },
	{ Discretizer::discr_t::NOPRINT, "rerrorrate", 3, (double *)&b_rates, (char **)&l_llmh },
	{ Discretizer::discr_t::NOPRINT, "srvrerrorrate", 3, (double *)&b_rates, (char **)&l_llmh },
	{ Discretizer::discr_t::DOUBLE, "samesrvrate", 3, (double *)&b_rates, (char **)&l_llmh },
	{ Discretizer::discr_t::DOUBLE, "diffsrvrate", 3, (double *)&b_rates, (char **)&l_llmh },
	{ Discretizer::discr_t::DOUBLE, "srvdiffhostrate", 3, (double *)&b_rates, (char **)&l_llmh },
	{ Discretizer::discr_t::NOPRINT, "dsthostcount", 1, (double *)&b_dst_count, (char **)&l_lh },
	{ Discretizer::discr_t::NOPRINT, "dsthostsrvcount", 1, (double *)&b_dst_count, (char **)&l_lh },
	{ Discretizer::discr_t::DOUBLE, "dsthostsamesrvrate", 3, (double *)&b_rates, (char **)&l_llmh },
	{ Discretizer::discr_t::DOUBLE, "dsthostdiffsrvrate", 3, (double *)&b_rates, (char **)&l_llmh },
	{ Discretizer::discr_t::DOUBLE, "dsthostsamesrcportrate", 3, (double *)&b_rates, (char **)&l_llmh },
	{ Discretizer::discr_t::DOUBLE, "dsthostsrvdiffhostrate", 3, (double *)&b_rates, (char **)&l_llmh },
	{ Discretizer::discr_t::NOPRINT, "dsthostserrorrate", 3, (double *)&b_rates, (char **)&l_llmh },
	{ Discretizer::discr_t::DOUBLE, "dsthostsrvserrorrate", 3, (double *)&b_rates, (char **)&l_llmh },
	{ Discretizer::discr_t::NOPRINT, "dsthostrerrorrate", 3, (double *)&b_rates, (char **)&l_llmh },
	{ Discretizer::discr_t::NOPRINT, "dsthostsrvrerrorrate", 3, (double *)&b_rates, (char **)&l_llmh },
	{ Discretizer::discr_t::NOPRINT, "srcip", 0, nullptr, nullptr },
	{ Discretizer::discr_t::NOPRINT, "srcport", 0, nullptr, nullptr },
	{ Discretizer::discr_t::PRINT,"dst_ip", 0, nullptr, nullptr },
	//{ Discretizer::discr_t::NOPRINT, "dst_port", 0, nullptr, nullptr },
	//{ Discretizer::discr_t::NOPRINT, "connendtime", 0, nullptr, nullptr },
	//{ Discretizer::discr_t::NOPRINT,  "label", 0, nullptr, nullptr }
};
const int Discretizer::n_recs = sizeof(recs) / sizeof(Discretizer::discr_t);

bool Discretizer::get_next_line(string &line)
{
	if (!cin.good()) {
		line = "";
		return false;
	}

	string s;
	cin >> s;


	stringstream ss;
	int col_i = 0;
	char value[30];	// should be enough
	const char *first_char = s.c_str();
	const char *c;
	for (c = first_char; (*c != '\0') && (col_i < n_recs); c++) {
		// Continue only when whole value found
		if (*c != ',')
			continue;

		int len = c - first_char;
		strncpy_s(value, sizeof(value), first_char, len);
		value[len] = '\0';

		write_column(ss, col_i, value);

		// Skip comma & set new value begining
		if (*(++c) == '\0')
			break;
		first_char = c;
		col_i++;
	}

	// Last column
	if ((col_i == n_recs - 1) && (*c == '\0')) {
		int len = c - first_char;
		strncpy_s(value, sizeof(value), first_char, len);
		value[len] = '\0';

		write_column(ss, col_i, value);
	}

	//
	if (col_i < n_recs - 1) {
		line = "Error parsing line: not enought columns";
		cerr << line;
		//exit(1);
		return false;
	}

	line = ss.str();
	return true;
}

void Discretizer::write_column(stringstream &ss, int col_i, char *value)
{
	int vi;
	double vd;

	switch (recs[col_i].type) {
	case discr_t::INT:
		vi = atoi(value);
		ss << recs[col_i].name << "," << get_label(col_i, vi);
		if (col_i < n_recs - 2)
			ss << ",";
		break;

	case discr_t::DOUBLE:
		vd = stod(value);
		ss << recs[col_i].name << "," << get_label(col_i, vd);
		if (col_i < n_recs - 2)
			ss << ",";
		break;

	case discr_t::PRINT:
		ss << recs[col_i].name << "," << value;
		if (col_i < n_recs - 2)
			ss << ",";
		break;

	default:
		// Nasrac, nothing to do
		break;
	}
}

const char *Discretizer::get_label(int col_i, double value)
{
	int i;
	for (i = 0; (i < recs[col_i].count); i++) {
		if (value <= recs[col_i].bounds[i])
			return recs[col_i].labels[i];
	}

	// All bounds passed, return last label
	return recs[col_i].labels[i];
}

const vector<string> strSplit(const string& s, const char& c)
{
	string buff("");
	vector<string> v;
	
	for(auto n:s)
	{
		if(n != c) buff+=n; else
		if(n == c && buff != "") { v.push_back(buff); buff = ""; }
	}
	if(buff != "") v.push_back(buff);
	
	return v;
}

vector<string> eraseMissingFeatures(DSL_network net, vector<string> evidenceVariables){

	for(vector<string>::iterator evidenceIterator = evidenceVariables.begin(); evidenceIterator != evidenceVariables.end();){
		
			bool erased = false;
			int nodeId = net.FindNode(evidenceIterator->c_str());
			if(nodeId < 0){
			
				evidenceVariables.erase(evidenceIterator);
				erased = true;
			}

			if(!erased){
			
				evidenceIterator++;
			}
		}
	return evidenceVariables;
}

DSL_network setTemporalStates(DSL_intArray networkNodes, DSL_network net){

	//for every node set temporatl type of platenode
	for(int i = 0; i < networkNodes.NumItems(); i++){
	
		//check if the node allready has a plate node type
		if(net.GetTemporalType(networkNodes[i]) != dsl_plateNode){
		
			int typeChanged = net.SetTemporalType(networkNodes[i], dsl_plateNode);
			if(typeChanged >= 0){
		
				//set the parents of parents while no change recursively
				net = setTemporalStates(net.GetParents(networkNodes[i]), net);
			}
		}
		
	}
	return net;
}

//method to remember evidence variable names AKO PICUS
map<string, string> getEvidenceVariables(vector<string> evidence){

	map<string, string> evidenceVariables;

	for(vector<string>::iterator evidenceIterator = evidence.begin(); evidenceIterator != evidence.end(); evidenceIterator++){
	
		string header = *evidenceIterator;
		evidenceIterator++;
		string value = *evidenceIterator;
		evidenceVariables[header] = value;
		
	}
	return evidenceVariables;
}

void learnDynamicEM(DSL_dataset &dynamicDataset, DSL_network &net, DSL_errorStringHandler er, string datasetName){

	DSL_em em;
	cout << "parameter learning starts\n";
	if (dynamicDataset.ReadFile(datasetName) != DSL_OKAY) {
     
		int err = er.GetLastError();
		cout << er.GetErrorMessage(err) << "Cannot read data file... exiting." << endl;
		system("PAUSE");
		exit(1);
	}
	
	//map the dynamic dataset
	vector<DSL_datasetMatch> dsMap(dynamicDataset.GetNumberOfVariables());
	for (int i = 0; i < dynamicDataset.GetNumberOfVariables(); i++) {
     
		string id = dynamicDataset.GetId(i);
		//if(i == 0){id = id.substr(3, (id.size() - 1));}
		const char* idc = id.c_str();
		bool done = false;
		for (int j = 0; j < (int) strlen(idc) && !done; j++) {

			if (idc[j] == '_') {
         
				// get the node handle:
				char* nodeId = (char*) malloc((j+1) * sizeof(char));
				strncpy(nodeId, idc, j);
				nodeId[j] = '\0';
           
				int nodeHdl = net.FindNode(nodeId);
				//assert(nodeHdl >= 0);
				DSL_intArray orders;
				net.GetTemporalOrders(nodeHdl, orders);
           
				dsMap[i].node   = nodeHdl;
				dsMap[i].slice  = atoi(idc + j + 1);
				dsMap[i].column = i;
           
				free(nodeId);
				done = true;
			}
		}
		if (!done) {
        
			int nodeHdl = net.FindNode(idc);
			if(nodeHdl < 0){
			
				cout << "label doesnt exist";
				system("PAUSE");
				exit(1);
			}
			//assert(nodeHdl >= 0);
			dsMap[i].node   = nodeHdl;
			dsMap[i].slice  = 0;
			dsMap[i].column = i;
		}
	}
	//map the dynamic dataset
	for (int i = 0; i < dynamicDataset.GetNumberOfVariables(); i++) {
     
		DSL_datasetMatch &p = dsMap[i];
		int nodeHdl = p.node;
		DSL_nodeDefinition* def = net.GetNode(nodeHdl)->Definition();
		DSL_idArray* ids = def->GetOutcomesNames();
		const DSL_datasetVarInfo &varInfo = dynamicDataset.GetVariableInfo(i);
		const vector<string> &stateNames = varInfo.stateNames;
		vector<int> map(stateNames.size(), -1);
			 
		for (int j = 0; j < (int) stateNames.size(); j++) {
        
			const char* id = stateNames[j].c_str();
				 
			for (int k = 0; k < ids->NumItems(); k++) {
           
				char* tmpid = (*ids)[k];
				if (!strcmp(id, tmpid)) {
              
					map[j] = k;
				}
			}
		}
		for (int k = 0; k < dynamicDataset.GetNumberOfRecords(); k++) {
				 
			if (dynamicDataset.GetInt(i, k) >= 0) {
					
				dynamicDataset.SetInt(i, k, map[dynamicDataset.GetInt(i, k)]);
			}
		}
	}
	//make network dynamic
	/*DSL_intArray netNodes;
	net.GetAllNodes(netNodes);
	net = setTemporalStates(netNodes, net);
	//set the temporal arc of 1st order for feature "label" (attack/normal activity)
	net.AddTemporalArc(net.FindNode("label"), net.FindNode("label"), 1);*/
	//learn dynamic inference
	if (em.Learn(dynamicDataset, net, dsMap) != DSL_OKAY) {
    
		cout << "Cannot learn parameters... exiting." << endl;
		exit(1);
	}
	cout << "parameter learning ends\n";
	net.WriteFile("tmp.xdsl",  DSL_XDSL_FORMAT);
}

int getPositionOfEvidence(DSL_network &net){

	DSL_Dmatrix* probmatrix = net.GetNode(net.FindNode("label"))->Value()->GetMatrix();
	int bestPosition;
	double biggestProbability = 0;
	int count = probmatrix->GetSize();
	int position = 0;
	for (int i = count - 2; i < count; i++, position++){
	
		//cout << (*probmatrix)[i] << " ";
		if((*probmatrix)[i] > biggestProbability){
		
			biggestProbability = (*probmatrix)[i];
			bestPosition = position;
		}
	}
//	cout << "\n";
	cout << biggestProbability << " ";
	return bestPosition;
}

vector<vector<map<string, string>>> updateScannedHostsList(map<string, Host>& scannedHosts, string actualHost){

	vector<vector<map<string, string>>> accumulatedEvicendes;
	
	for(map<string, Host>::iterator scannedHostsIterator = scannedHosts.begin(); scannedHostsIterator != scannedHosts.end();){
	
		bool deleted = false;
		if(actualHost.compare(scannedHostsIterator->first) != 0){

			if(scannedHostsIterator->second.getCounter() > 100){
			
				vector<map<string, string>> accev = scannedHostsIterator->second.accumulatedEvidence;
				accumulatedEvicendes.push_back(accev);
				scannedHostsIterator = scannedHosts.erase(scannedHostsIterator);
				deleted = true;
			}else{
			
				scannedHostsIterator->second.setCounter(scannedHostsIterator->second.getCounter() + 1);
			}
		}else{
		
			scannedHostsIterator->second.setCounter(0);
		}
		if(!deleted){
		
			scannedHostsIterator++;
		}
	}
	return accumulatedEvicendes;
}

void updateDataset(vector<map<string, string>> accumulatedEvidence){

	map<string, vector<string>> evidenceMap;

	//for every line of evidence
	for(vector<map<string, string>>::iterator accumulatedEvidenceIterator = accumulatedEvidence.begin(); accumulatedEvidenceIterator != accumulatedEvidence.end(); accumulatedEvidenceIterator++){
	
		//for every feature of a line of the evidence
		for(map<string, string>::iterator evidenceIterator = accumulatedEvidenceIterator->begin(); evidenceIterator != accumulatedEvidenceIterator->end(); evidenceIterator++){
		
			//check if key is allready in map
			map<string, vector<string>>::iterator it = evidenceMap.find(evidenceIterator->first);
			if(it != evidenceMap.end()){
			
				//add new evidence for this feature
				evidenceMap.find(evidenceIterator->first)->second.push_back(evidenceIterator->second);
			}else{
			
				//create space for this feature annd add new evidence to it
				vector<string> evidenceValues;
				evidenceValues.push_back(evidenceIterator->second);
				evidenceMap.insert(pair<string,vector<string>>(evidenceIterator->first, evidenceValues));
			}
		}
	}

	string headerString;
	string dataString;
	for(map<string, vector<string>>::iterator evidenceMapIterator = evidenceMap.begin(); evidenceMapIterator != evidenceMap.end(); evidenceMapIterator++){
	
		if(evidenceMapIterator->first.compare("dst_ip") == 0){continue;}
		for(int i = 0; i < evidenceMapIterator->second.size(); i++){

			if(i == 0){
			
				headerString += evidenceMapIterator->first + " ";
			}else{
			
				headerString += evidenceMapIterator->first + "_" + std::to_string(i) + " ";
			}
		}
		int i = 1;
		for(vector<string>::iterator evidenceIterator = evidenceMapIterator->second.begin(); evidenceIterator != evidenceMapIterator->second.end(); evidenceIterator++){
		
			dataString += *evidenceIterator + " ";
		}
	}

	headerString = headerString.substr(0, headerString.size() - 1);
	dataString = dataString.substr(0, dataString.size() - 1);

	ofstream tmpfile;
	tmpfile.open("newEvidence.txt");

	tmpfile << headerString << "\n" << dataString;

	tmpfile.close();
}


void usage(char *name)
{
	cout << "Usage: " << name << " [OPTION]... [FILE]" << endl
		<< "FILE           Network filename" << endl
		<< " -l,           Enable learning" << endl
		<< " -s,           Save parameter  " << endl
		<< " -d   FILE     Dataset filenae" << endl
		<< " -o   FILE     Output network filename" << endl
		<< endl;
}

void invalid_option(char *opt, char *progname)
{
	cout << "Invalid option '" << opt << "'" << endl << endl;
	usage(progname);
	exit(1);
}

void invalid_option_value(char *opt, char *val, char *progname)
{
	cout << "Invalid value '" << val << "' for option '" << opt << "'" << endl << endl;
	usage(progname);
	exit(1);
}

int main(int argc, char **argv){

	DSL_dataset staticDataset;
	DSL_dataset dynamicDataset;
	DSL_network net;
	DSL_errorStringHandler er;
	DSL_em em;

	bool learningParameter = false;
	bool savingParameter = false;
	string networkName;
	string datasetName;
	string saveNetworkName;

	// Parse arguments 
	if (argc < 2) {
		cout << "Too few arguments." << endl << endl;
		usage(argv[0]);
		exit(1);
	}

	for (int i = 1; i < argc; i++) {
		// Network filename
		if (argv[i][0] != '-') {
			networkName = argv[i];
			continue;
		}

		size_t len = strlen(argv[i]);
		if (len < 2)
			invalid_option(argv[i], argv[0]);

		switch (argv[i][1]) {
		case '-': // Long option
			if (strcmp(argv[i], "--help") == 0) {
				usage(argv[0]);
				exit(0);
			}

			invalid_option(argv[i], argv[0]);
			break;

		case 'h':
			usage(argv[0]);
			exit(0);
			break;

		case 'l':
			if (len != 2)
				invalid_option(argv[i], argv[0]);
			learningParameter = true;
			break;

		case 's':
			if (len != 2)
				invalid_option(argv[i], argv[0]);
			savingParameter = true;
			break;

		case 'd':
			if (len != 2)
				invalid_option(argv[i], argv[0]);
			if (argc <= ++i)
				invalid_option_value(argv[i - 1], "", argv[0]);

			datasetName = argv[i];
			break;

		case 'o':
			if (len != 2)
				invalid_option(argv[i], argv[0]);
			if (argc <= ++i)
				invalid_option_value(argv[i - 1], "", argv[0]);

			saveNetworkName = argv[i];
			break;
		}
	}
	if (networkName.empty()) {
		cout << "Network filename argument missing." << endl << endl;
		usage(argv[0]);
		exit(1);
	}

	if (net.ReadFile(networkName.c_str(), DSL_XDSL_FORMAT) != DSL_OKAY) {
     
		cout << "cannot read network... exiting." << endl;
		system("PAUSE");
		exit(1);
	}

	if(learningParameter){
	
		learnDynamicEM(dynamicDataset, net, er, datasetName);

		if(savingParameter){
		
			saveNetworkName += ".xdsl";
			net.WriteFile(saveNetworkName.c_str(), DSL_XDSL_FORMAT);
		}
	}
	
	//new line of evidence
	string line;
	map<string, Host> scannedHosts;
	//cout << "zajeb kokotinu: ";
	while(Discretizer::get_next_line(line)){
	
		//destination host of currently handled connection
		Host *currentHost;
		vector<string> evidence (strSplit(line, ','));
		//get the map of key:header->value:value of header evidence
		map<string, string> evidenceVariables = getEvidenceVariables(evidence);
		//get the destination ip
		string dst_ip = evidenceVariables.find("dst_ip")->second;
		//check if the host is already scanned
		map<string,Host>::iterator it = scannedHosts.find(dst_ip);
		if(it == scannedHosts.end()){
		
			//if not create a new network for this host
			DSL_network* newNet = new DSL_network(net);
			Host host;
			host.setName(dst_ip);
			newNet->SetNumberOfSlices(1);
			host.setNetwork(newNet);

			//add a host to the list of scanned hosts
			scannedHosts.insert(pair<string,Host>(dst_ip,host));

			currentHost = &scannedHosts.find(dst_ip)->second;
		}else{
		
			//if not, increment the timeslice count for this host
			currentHost = &scannedHosts.find(dst_ip)->second;
			currentHost->getNetwork()->SetNumberOfSlices(currentHost->getNetwork()->GetNumberOfSlices() + 1);
		}
		//save the evidence to current host
		currentHost->accumulatedEvidence.push_back(evidenceVariables);
		int numberOfNodes = currentHost->getNetwork()->GetNumberOfNodes();
		//set an evidence for every node
		for(int i = 0; i < numberOfNodes; i++){
		
			//get the possible states of the node
			DSL_node* nodeskurvety = net.GetNode(i);
			DSL_node* node = currentHost->getNetwork()->GetNode(i);
			DSL_nodeValue* nv = node->Value();
			const DSL_idArray &states = *(node->Definition()->GetOutcomesNames());

			//check if the node is available in the evidence
			map<string,string>::iterator it = evidenceVariables.find(node->GetId());
			string stateName;
			//if the node is available in the evidence and it is not label node, set temporal evidence for it
			if(it != evidenceVariables.end() && (it->first.compare("label") != 0)){
			
				//set the state name
				stateName = evidenceVariables.find(node->GetId())->second;
				int statePosition = states.FindPosition(stateName.c_str());
				//set the temporal evidence for this node at current time slice
				int skuska = nv->SetTemporalEvidence(currentHost->getNetwork()->GetNumberOfSlices() - 1, statePosition);
				//cout << evidenceVariables.find(node->GetId())->first << " setevidence returnvalue " << skuska << " " << states[node->Value()->GetTemporalEvidence(0)] << " " << states[statePosition] << "\n";
			}
		}
		//update the network belief
		currentHost->getNetwork()->UpdateBeliefs();
		//return the position of state of the label node, which has bigger probability
		int evidenceStatePosition = getPositionOfEvidence(*(currentHost->getNetwork()));

		cout << evidenceStatePosition << "\n";// << "slice: " << currentHost.getNetwork()->GetNumberOfSlices() << " ";
		//set an evidence for a label node
		//currentHost.getNetwork()->GetNode(currentHost.getNetwork()->FindNode("label"))->Value()->SetTemporalEvidence(currentHost.getNetwork()->GetNumberOfSlices() - 1, evidenceStatePosition);
		
		//remove the hosts whose timeslices count are below threshold (havent been updated in a while)
		vector<vector<map<string, string>>> accumulatedEvidences = updateScannedHostsList(scannedHosts, currentHost->getName());
		
		//if there was a deleted host
		if(!accumulatedEvidences.empty()){

			//update the network from accumulated evidence of every recently deleted host
			for(vector<vector<map<string, string>>>::iterator accumulatedEvidencesIterator = accumulatedEvidences.begin(); accumulatedEvidencesIterator != accumulatedEvidences.end(); accumulatedEvidencesIterator++){
			
				updateDataset(*accumulatedEvidencesIterator);
				learnDynamicEM(dynamicDataset, net, er, "newEvidence.txt");
			}
		}
	}

	system("PAUSE");
	return 0;
}