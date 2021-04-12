#include <vector>
#include <string>
#include <map>
#include <iostream>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
using namespace std;

struct command {
	string commandName;
   vector<string> args;
	string inputFileName;
   string outputFileName;
};

char* subAliases(char* name);

extern map<string,string> envMap;
extern map<string,string> aliasMap;
extern struct vector<command> commandTable;