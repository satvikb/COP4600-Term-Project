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
   bool outputAppend;
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

struct outputFileCmd {
   string fileName;
   int append = 0;
};

list* newArgList();
pipedCmds* newPipedCmdList();
pipedCmds* appendToCmdList(pipedCmds* p, char* name, list* args);

char* subAliases(char* name);
void updateParentDirectories(string path);

extern map<string,string> envMap;
extern map<string,string> aliasMap;
extern string CURRENT_DIR;
extern struct vector<command> commandTable;