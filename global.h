#include <vector>
#include <string>
#include <iostream>
#include <errno.h>
using namespace std;

struct evTable {
   char var[128][100]; // array of strings max length of 100
   char word[128][100];
};
struct aTable {
	char name[128][100];
	char word[128][100];
};
struct command {
	string commandName;
   vector<string> args;
	string inputFileName;
   string outputFileName;
};


char* subAliases(char* name);

extern struct evTable varTable;
extern struct aTable aliasTable;
extern struct vector<command> commandTable;
// extern struct command commandTable[32];
extern int aliasIndex;
extern int varIndex;
