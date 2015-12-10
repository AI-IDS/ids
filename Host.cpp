#include "Host.h"


Host::Host(void)
{
}


Host::~Host(void)
{
}

void Host::setName(std::string hostname){

	this->name = hostname;
}

std::string Host::getName(){

	return this->name;
}

void Host::setNetwork(DSL_network *networkName){

	this->net = networkName;
}

DSL_network* Host::getNetwork(){

	return this->net;
}

int Host::getCounter(){

	return this->counter;
}

void Host::setCounter(int count){

	this->counter = count;
}

std::vector<std::map<std::string,std::string>> Host::getAccumulatedEvidence(){

	return this->accumulatedEvidence;
}