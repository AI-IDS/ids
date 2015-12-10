#pragma once
#include "smilearn.h"
#include "smile.h"
#include "string.h"

class Host
{
public:
	Host(void);
	~Host(void);
	void setName(std::string hostname);
	std::string getName();
	void setNetwork(DSL_network *networkName);
	DSL_network* getNetwork();
	int getCounter();
	void setCounter(int count);
	std::vector<std::map<std::string,std::string>> getAccumulatedEvidence();
	std::vector<std::map<std::string,std::string>> accumulatedEvidence;
private:
	DSL_network *net;
	std::string name;
	int counter;
	
};

