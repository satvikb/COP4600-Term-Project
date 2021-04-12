#include <vector>
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
	char *commandName;
   int numberArguments;
   char *args; // TODO, this should be a pointer to a list of strings/char[] (or one string) with each arg being null terminated
	char *inputFileName;
   char *outputFileName;
};

struct commandpipe {
	char *commandName;
   int numberArguments;
   char *args; // TODO, this should be a pointer to a list of strings/char[] (or one string) with each arg being null terminated
	// int inputPipe[2];
   // int outputPipe[2];
};
char* subAliases(char* name);

extern struct evTable varTable;
extern struct aTable aliasTable;
extern struct vector<command> commandTable;
// extern struct command commandTable[32];
extern int aliasIndex;
extern int varIndex;
