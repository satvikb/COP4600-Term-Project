// This is ONLY a demo micro-shell whose purpose is to illustrate the need for and how to handle nested alias substitutions and Flex start conditions.
// This is to help students learn these specific capabilities, the code is by far not a complete nutshell by any means.
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

struct evTable varTable;
struct aTable aliasTable;

// int lenCommandTable = 32;
struct command commandTable[32];

int aliasIndex, varIndex;
char* subAliases(char* name);
