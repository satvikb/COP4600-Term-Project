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

int runSetEnv(char *variable, char *word);
int runCommandTable(struct vector<command> commandTable);

void runExampleCommand();
void printFileName(int fd);
%}

%union {char *string;}

%start cmd_line
%token <string> BYE CD STRING ALIAS UNALIAS SETENV UNSETENV PRINTENV EC END CUSTOM_CMD

%%
cmd_line    :
	BYE END 		                {exit(1); return 1; }
	| CD STRING END        			{runCD($2); return 1;}
	| SETENV STRING STRING END	{runSetEnv($2, $3); return 1;}
	| ALIAS STRING STRING END		{runSetAlias($2, $3); return 1;}
	| EC END					          {runExampleCommand(); return 1;}
	| CUSTOM_CMD END				    {printf("%s\n", "success"); return 1;}
%%

int yyerror(char *s) {
  printf("%s\n",s);
  return 0;
}

int runCD(char* arg) {
	if (arg[0] != '/') { // arg is relative path
		strcat(varTable.word[0], "/"); // add a / to the current path
		strcat(varTable.word[0], arg); // append the arg to the current path + /

		// if error, shouldnt varTable.word[0] be reset to before concat?
		if(chdir(varTable.word[0]) == 0) {  // change working directory
			strcpy(aliasTable.word[0], varTable.word[0]); // set . to dir
			strcpy(aliasTable.word[1], varTable.word[0]); // set .. to dir (?)

			// not sure what the point of this is
			char *pointer = strrchr(aliasTable.word[1], '/');
			while(*pointer != '\0') {
				*pointer ='\0';
				pointer++;
			}
		}
		else {
			//strcpy(varTable.word[0], varTable.word[0]); // fix
			printf("Directory not found\n");
			return 1;
		}
	}
	else { // arg is absolute path
		if(chdir(arg) == 0){ // change dir
			strcpy(aliasTable.word[0], arg); // set . to arg
			strcpy(aliasTable.word[1], arg); // set .. to arg (?)
			strcpy(varTable.word[0], arg); // set PWD to arg

			// ?
			char *pointer = strrchr(aliasTable.word[1], '/');
			while(*pointer != '\0') {
				*pointer ='\0';
				pointer++;
			}
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
	for (int i = 0; i < aliasIndex; i++) {
		// initial check, start of cycle
		if(strcmp(aliasTable.name[i], word) == 0){
			if(strcmp(aliasTable.word[i], name) == 0){
				// cycle, invalid
				return true;
			}
			return checkIfWordEndsAtName(aliasTable.word[i], name); // check if two ends at three
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
	for (int i = 0; i < aliasIndex; i++) {
		// test if this combination already exists
		if((strcmp(aliasTable.name[i], name) == 0) && (strcmp(aliasTable.word[i], word) == 0)){
			printf("Error, expansion of \"%s\" would create a loop.\n", name);
			return 1;
		}
		// check if name/alias already exists, override if it does
		else if(strcmp(aliasTable.name[i], name) == 0) {
			strcpy(aliasTable.word[i], word);
			return 1;
		}else if(checkIfWordEndsAtName(name, word) == true){
			printf("Cycle.");
			return 1;
		}
	}
	// new alias
	strcpy(aliasTable.name[aliasIndex], name);
	strcpy(aliasTable.word[aliasIndex], word);
	aliasIndex++;

	return 1;
}

int runSetEnv(char *variable, char *word){
	// actually same word as variable should be okay
	/* if(strcmp(variable, word) == 0){
		// same
		return 1;
	} */
	printf("Setting var name \"%s\".\n", variable);
	for(int i = 0; i < varIndex; i++){
		// override existing var
		if(strcmp(varTable.var[i], variable) == 0) {
			printf("Override var \"%s\" to word \"%s\".\n", variable, word);
			strcpy(varTable.word[i], word);
			return 1;
		}
	}

	printf("New var \"%s\" to word \"%s\".\n", variable, word);
	// new alias
	strcpy(varTable.var[varIndex], variable);
	strcpy(varTable.word[varIndex], word);
	varIndex++;

	return 1;
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
			Input for 0: [3,4]
			Output for 1: [5,6]
			Input for 2: [7,8]
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

	// 2nd loop - handle redirection
	for(int i = 0; i < validCommandCount; i++){
		command cmd = commandTable[i];
		
		if(cmd.inputFileName[0] != '\0'){ // 2 - check if input file is not null
			// open file, write data to pipe. maybe wait to write until command starts running
			// to prevent buffer limit / deadlock?
		}

		bool lastElement = i == validCommandCount-1;

		// if(i == 0){
		// 	cout << "SETTING INPUT FOR FIRST COMMAND" << endl;
		// 	// dup2(pipes[INPUT(i)][WRITE_END], STDIN_FILENO);
		// 	dup2(STDIN_FILENO, pipes[INPUT(i)][WRITE_END]);
		// }
		// HANDLE OUTPUT
		if (lastElement || cmd.outputFileName[0] != '\0'){
			// this is the last command or outfile file isnt empty
			if(lastElement){
				// revert standard out
				cout << "BACK TO STDOUT " << OUTPUT(i) << endl;
				// dup2(STDOUT_FILENO, pipes[OUTPUT(i)][WRITE_END]); // confirmed right
			}else{
				// TODO write to file
			}
		}else{
			// first or middle command, redirect from prev
			// output of this command goes to next command
			// dup2(pipes[INPUT(i+1)][WRITE_END], pipes[OUTPUT(i)][READ_END]);
			// close(pipes[OUTPUT(i)][READ_END]);
		}
	}
	
	cout << "PRINTING PIPES " << validCommandCount << endl;
	// print pipes for debug
	for(int i = 0; i < validCommandCount; i++){
		command cmd = commandTable[i];
		bool lastElement = i == validCommandCount-1;
		// cout << "[" << cmd.commandName << "]" << " Child. Input pipe: " << pipes[INPUT(i)][0] << "/" << pipes[INPUT(i)][1] << ". Last cmd: " << lastElement << endl;
		cout << "[" << cmd.commandName << "]" << " Child. Output pipe: " << pipes[OUTPUT(i)][0] << "/" << pipes[OUTPUT(i)][1] << ". Last cmd: " << lastElement << endl;

		// printFileName(pipes[INPUT(i)][0]);
		// printFileName(pipes[INPUT(i)][1]);
		printFileName(pipes[OUTPUT(i)][0]);
		printFileName(pipes[OUTPUT(i)][1]);

	}
	
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

			cout << "CLOSING CHILD PIPES" << endl;
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
