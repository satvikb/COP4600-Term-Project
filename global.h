#include <vector>
#include <string>
#include <map>
#include <iostream>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <pwd.h>
#include <cstddef> 
using namespace std;

struct command {
	string commandName;
   vector<string> args;
	string inputFileName;
   string outputFileName;
};

void updateParentDirectories(string path);

char* subAliases(char* name);

extern map<string,string> envMap;
extern map<string,string> aliasMap;
extern struct vector<command> commandTable;