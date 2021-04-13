#include <vector>
#include <string>
#include <map>
#include <iostream>
#include <errno.h>
using namespace std;

struct command {
	string commandName;
   vector<string> args;
	string inputFileName;
   string outputFileName;
};

struct list {
	char args[128][100];
	int size = 0;
};

struct nestedCmd {
   list* args = NULL;
   char name[128];
};

struct pipedCmds {
   vector<nestedCmd*> commands;
};

list* newArgList();
pipedCmds* newPipedCmdList();
pipedCmds* appendToCmdList(pipedCmds* p, char* name, list* args);

char* subAliases(char* name);

extern map<string,string> envMap;
extern map<string,string> aliasMap;
extern struct vector<command> commandTable;