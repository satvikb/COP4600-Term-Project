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
#include <algorithm>
#include "dirent.h"
#include <fnmatch.h>
#include<iterator>
using namespace std;

typedef map<string, string> TStrStrMap;

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

struct outputFileCmd {
   string fileName;
   int append = 0;
};

struct errorOutput {
   string fileName = "";
   int toFile = 0;
};

list* newArgList();
pipedCmds* newPipedCmdList();
pipedCmds* appendToCmdList(pipedCmds* p, char* name, list* args);

char* subAliases(char* name);
void updateParentDirectories(string path);
const char* getHomeDirectory();
string expandDirectory(string arg);
string completeString(string partial);

extern map<string,string> envMap;
extern map<string,string> aliasMap;
extern map<string, string> systemUsers;
extern string CUR_ESC_PATH;
extern string CURRENT_DIR;
extern struct vector<command> commandTable;

TStrStrMap::const_iterator FindPrefix(const TStrStrMap& map, const string& search_for);