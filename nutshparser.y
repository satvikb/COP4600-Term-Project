%{
// This is ONLY a demo micro-shell whose purpose is to illustrate the need for and how to handle nested alias substitutions and Flex start conditions.
// This is to help students learn these specific capabilities, the code is by far not a complete nutshell by any means.
// Only "alias name word", "cd word", and "bye" run.


/*
strcpy (dest, source) - copy from source to dest
strrchr (string, char) - return pointer to last occurance of character in str. null ptr if nothing
strcat (destination, source) - appends copy of source to destination (replace end of null in dest, add null to source)
chdir (path) - change working directory

*/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <vector>
#include <sys/wait.h>
#include "global.h"

#define READ_END 0
#define WRITE_END 1

// #define INPUT(i) i*2
#define OUTPUT(i) i //(i*2)+1

int yylex(); 
int yyerror(char *s);

int runCD(char* arg);

bool checkIfWordEndsAtName(char *name, char *word);
int runSetAlias(char *name, char *word);
int runPrintAlias();
void unsetAlias(char* name);

int runSetEnv(char *variable, char *word);
int runPrintVariable();
void unsetVariable(char* variable);

int runCommandTable(struct vector<command> commandTable);

void runExampleCommand();
void printFileName(int fd);
%}

%code requires {
    struct list {
        char args[128][100];
   		int size = 0;
    };

	list* newArgList();
}

%union {
		char *string;
		struct list* arguments;
	}

%start cmd_line
%token <string> BYE CD STRING ALIAS UNALIAS SETENV UNSETENV PRINTENV END CUSTOM_CMD
%token PIPE "|"
%token IN "<"
%token OUT ">"
%token A_OUT ">>"

%nterm <arguments> arg_list

%%
cmd_line    :
	BYE END 		                {exit(1); return 1; }
	| CD STRING END        			{runCD($2); return 1;}
	| SETENV STRING STRING END		{runSetEnv($2, $3); return 1;}
	| UNSETENV STRING END			{unsetVariable($2); return 1;}
	| PRINTENV END					{runPrintVariable(); return 1;}
	| ALIAS STRING STRING END		{runSetAlias($2, $3); return 1;}
	| ALIAS END						{runPrintAlias(); return 1;}
	| UNALIAS STRING END			{unsetAlias($2); return 1;}
	| CUSTOM_CMD arg_list END		{
										printf("%s\n", $1); 
										
										for(int i = 0; i < ($2)->size; i++) {
											printf("%s\t", $2->args[i]);
										}
										printf("\n");
										
										return 1;
									}

arg_list    :
	%empty							{$$ = newArgList();}
	| arg_list STRING               {$$ = $1; strcpy($$->args[$$->size], $2); $$->size++;}
%%

int yyerror(char *s) {
  printf("%s\n",s);
  return 0;
}

list* newArgList() {
	list* l = (struct list*) malloc(sizeof(struct list));
	return l;
}


int runCD(char* arg) {
	if (arg[0] != '/') { // arg is relative path

		// add a / to the current path
		// append the arg to the current path + /
		string newPath = envMap["PWD"]+"/"+arg;

		// if error, shouldnt varTable.word[0] be reset to before concat?
		if(chdir(newPath.c_str()) == 0) {  // change working directory

			envMap["PWD"] = newPath;
			// strcpy(aliasTable.word[0], varTable.word[0]); // set . to dir
			// strcpy(aliasTable.word[1], varTable.word[0]); // set .. to dir (?)

			// not sure what the point of this is
			// char *pointer = strrchr(aliasTable.word[1], '/');
			// while(*pointer != '\0') {
			// 	*pointer ='\0';
			// 	pointer++;
			// }
		}
		else {
			//strcpy(varTable.word[0], varTable.word[0]); // fix
			printf("Directory not found\n");
			return 1;
		}
	}
	else { // arg is absolute path
		if(chdir(arg) == 0){ // change dir
			// strcpy(aliasTable.word[0], arg); // set . to arg
			// strcpy(aliasTable.word[1], arg); // set .. to arg (?)
			// strcpy(varTable.word[0], arg); // set PWD to arg
			envMap["PWD"] = arg;

			// ?
			// char *pointer = strrchr(aliasTable.word[1], '/');
			// while(*pointer != '\0') {
			// 	*pointer ='\0';
			// 	pointer++;
			// }
		}
		else {
			printf("Directory not found\n");
						return 1;
		}
	}
	return 1;
}


/*
existing:
alias one two
alias two three

ALIAS NAME WORD

to add:
alias three one

*/
// recursive
bool checkIfWordEndsAtName(char *name, char *word){
	map<string, string>::iterator it;
	for(it = aliasMap.begin(); it != aliasMap.end(); ++it){
		if(it->first == word){
			if(it->second == name){
				// cycle, invalid
				return true;
			}
			return checkIfWordEndsAtName(&it->second[0], name); // check if two ends at three
		}
	}
	return false;
}

// the alias is name, = word. word "shortened" to name / alias
int runSetAlias(char *name, char *word) {
	printf("Setting alias name \"%s\".\n", name);
	// test if name and word is the same
	if(strcmp(name, word) == 0){
		printf("Error, expansion of \"%s\" would create a loop.\n", name);
		return 1;
	}

	// loop through existing aliases
	map<string, string>::iterator it;
	for(it = aliasMap.begin(); it != aliasMap.end(); ++it){
		// test if this combination already exists
		if(it->first == name && it->second == word){
			printf("Error, expansion of \"%s\" would create a loop.\n", name);
			return 1;
		}else if(it->first == name){
			// check if name/alias already exists, override if it does
			aliasMap[it->first] = word;
			return 1;
		}else if(checkIfWordEndsAtName(name, word) == true){
			printf("Cycle.");
			return 1;
		}
	}

	// new alias
	aliasMap[name] = word;
	return 1;
}

int runPrintAlias(){
	map<string, string>::iterator it;
	for(it = aliasMap.begin(); it != aliasMap.end(); ++it){
		cout << it->first << "=" << it->second << endl;
	}
}

void unsetAlias(char* name){
	aliasMap.erase(name);
}

int runSetEnv(char *variable, char *word){
	printf("Setting var name \"%s\".\n", variable);
	// loop through existing aliases
	map<string, string>::iterator it;
	for(it = envMap.begin(); it != envMap.end(); ++it){
		if(it->first == variable){
			printf("Override var \"%s\" to word \"%s\".\n", variable, word);
			envMap[it->first] = word;
			return 1;
		}
	}

	printf("New var \"%s\" to word \"%s\".\n", variable, word);
	envMap[variable] = word;

	return 1;
}

int runPrintVariable(){
	map<string, string>::iterator it;
	for(it = envMap.begin(); it != envMap.end(); ++it){
		cout << it->first << "=" << it->second << endl;
	}
}

void unsetVariable(char* variable){
	envMap.erase(variable);
}

void runExampleCommand(){
	command start = { .commandName = "/bin/ls"};
	command cat = { .commandName = "/bin/cat"};
	vector<string> catArgs; catArgs.push_back("Makefile");
	// cat.args = catArgs;

	command grep = { .commandName = "/bin/grep"};
	vector<string> grepArgs; grepArgs.push_back("shell");
	grep.args = grepArgs;

	commandTable.push_back(start);
	commandTable.push_back(cat);
	commandTable.push_back(grep);


	printf("RUNNING COMMAND TABLE\n");
	runCommandTable(commandTable);
}

void printFileName(int fd){
	enum { BUFFERSIZE = 1024 };
	char buf1[BUFFERSIZE];
	string path = "/proc/self/fd/";
	path += std::to_string(fd);
	ssize_t len1 = readlink(path.c_str(), buf1, sizeof(buf1));
	if (len1 != -1) {buf1[len1] = '\0';}
	cout << fd << " FILE LINK " << buf1 << endl;
}
// ASSUMPTION: a command can only do one of either Output to file or Redirect into pipe, Not both.
// ^ so a command must end with | or > (if not using &1)

// ASSUMPTION: any command/multiple commands can have input files with <.
// ^ the spec however, only shows one < at the end of the line?
int runCommandTable(struct vector<command> commandTable){
	int pipes[commandTable.size()][2];
	/*
		pipes = 
		[
			Output for 1: [5,6]
			Output for 2: [9,10]
		]
	*/

	int validCommandCount = commandTable.size();
	// 1st loop through command table
	// initialize all pipes (just do pipe())
	for(int i = 0; i < commandTable.size(); i++){
		command cmd = commandTable[i];
		// pipe(pipes[INPUT(i)]);
		pipe(pipes[i]);
	}
	
	// cout << "PRINTING PIPES " << validCommandCount << endl;
	// // print pipes for debug
	// for(int i = 0; i < validCommandCount; i++){
	// 	command cmd = commandTable[i];
	// 	bool lastElement = i == validCommandCount-1;
	// 	// cout << "[" << cmd.commandName << "]" << " Child. Input pipe: " << pipes[INPUT(i)][0] << "/" << pipes[INPUT(i)][1] << ". Last cmd: " << lastElement << endl;
	// 	cout << "[" << cmd.commandName << "]" << " Child. Output pipe: " << pipes[OUTPUT(i)][0] << "/" << pipes[OUTPUT(i)][1] << ". Last cmd: " << lastElement << endl;

	// 	// printFileName(pipes[INPUT(i)][0]);
	// 	// printFileName(pipes[INPUT(i)][1]);
	// 	printFileName(pipes[OUTPUT(i)][0]);
	// 	printFileName(pipes[OUTPUT(i)][1]);

	// }
	
	// 3rd loop - execute commands, deal with actual files here
	for(int i = 0; i < validCommandCount; i++){
		command cmd = commandTable[i];

		if(fork() == 0){
			// execute command
			// generate argv

			char cmdNameC[cmd.commandName.length()+1];
			strcpy(cmdNameC, cmd.commandName.c_str());

			// create array of args
			//https://stackoverflow.com/questions/5797837/how-to-pass-a-vector-of-strings-to-execv
			const char **argv = new const char* [cmd.args.size()+2];
			argv[0] = cmdNameC;

			for(int i = 0; i < cmd.args.size(); i++){
				argv[i+1] = cmd.args[i].c_str();
			}
			argv[cmd.args.size()+1] = NULL;

			bool firstCommand = i == 0;
			bool lastCommand = i == validCommandCount - 1;

			if(firstCommand){
				// only assign stdout
				dup2(pipes[0][WRITE_END], STDOUT_FILENO);
			}
			if(lastCommand){
				// dont like having a special case like this
				if(validCommandCount <= 1){
					cout << "ONLY ONE COMMAND" << validCommandCount << endl;
					dup2(pipes[0][READ_END], STDIN_FILENO);
				}else{
					cout << "assigning input to last command" << cmd.commandName << endl;
					dup2(pipes[i-1][READ_END], STDIN_FILENO);
				}
				// assign to stdout
				dup2(STDOUT_FILENO, pipes[i][READ_END]);
				
			}
			if(!(firstCommand || lastCommand)){
				// middle command
				// assign stdin to be output from previous command
				dup2(pipes[i-1][READ_END], STDIN_FILENO);
				// assign cmd stdout to be current pipe write
				dup2(pipes[i][WRITE_END], STDOUT_FILENO);
			}

			cout << "CLOSING CHILD PIPES shell" << endl;
			close(pipes[i][READ_END]);
			close(pipes[i][WRITE_END]);

			if (execv(argv[0], (char **)argv) < 0){
				cout << "ERROR" << errno << endl;
				exit(0);
			}
		}
	}


	std::cout << "Closing all pipes" << endl;
	for(int i = 0; i < commandTable.size(); i++){
		command cmd = commandTable[i];
		close(pipes[i][READ_END]);
		close(pipes[i][WRITE_END]);

		// close(pipes[INPUT(i)][READ_END]);
		// close(pipes[INPUT(i)][WRITE_END]);
		// close(pipes[OUTPUT(i-1)][READ_END]);
		// close(pipes[OUTPUT(i-1)][WRITE_END]);

	}
	
	std::cout << "Waiting for all commands to finish " << validCommandCount << endl;
	// TODO handle the & and background processing. do that here (at the command level, race conditions between commands?)? or at the table level?
	int status;
	for (int i = 0; i < validCommandCount; i++)
		wait(&status);

	
	// reset commandTable here
	return 0;
}

// http://www.rozmichelle.com/pipes-forks-dups/
