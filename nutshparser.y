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

int yylex(); 
int yyerror(char *s);

int runCD(char* arg);

bool checkIfWordEndsAtName(char *name, char *word);
int runSetAlias(char *name, char *word);

int runSetEnv(char *variable, char *word);
int runCommandTable(struct vector<command> commandTable);

void runExampleCommand();
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
	| ALIAS STRING STRING END		{runSetAlias($2, $3); return 1;}
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
	command grep = { .commandName = "/bin/grep"};
	vector<string> grepArgs; grepArgs.push_back("shell");
	grep.args = grepArgs;

	commandTable.push_back(start);
	// commandTable.push_back(cat);
	commandTable.push_back(grep);


	printf("RUNNING COMMAND TABLE\n");
	runCommandTable(commandTable);
}

// ASSUMPTION: a command can only do one of either Output to file or Redirect into pipe, Not both.
// ^ so a command must end with | or > (if not using &1)

// ASSUMPTION: any command/multiple commands can have input files with <.
// ^ the spec however, only shows one < at the end of the line?
int runCommandTable(struct vector<command> commandTable){
	// loop through command table
	/*
	example:
			sort < colors.txt | uniq -c | sort -r | head -3 > favcolors.txt

			commandTable[0] = {CMD: sort, # arg: 0, args: nullptr, inputFileName: colors.txt, outputFile: null}
			commandTable[1] = {CMD: uniq, # arg: 1, args: [-c](?), input: null, output: null}
			commandTable[2] = {CMD: sort, # arg: 1, args: [-r](?), input: null, output: null}
			commandTable[3] = {CMD: head, # arg: 1, args: [-3](?), input: null, outputFileName: favcolors.txt}

	*/

	int validCommandCount = 0;

	vector<command>::iterator it = commandTable.begin();
	int i = 0;
	for(it = commandTable.begin(); it != commandTable.end(); it++,i++){
		command cmd = commandTable[i];
		if(cmd.commandName[0] != '\0'){
			pipe(cmd.outputPipe);

			if(cmd.inputFileName[0] != '\0'){ // 2 - check if input file is not null
				// open file, write data to pipe. maybe wait to write until command starts running
				// to prevent buffer limit / deadlock?

			}

			cout << "[" << cmd.commandName << "]" << " Begin pipe: " << cmd.outputPipe[0] << "/" << cmd.outputPipe[1] << endl;

			int pid = fork();
			if(pid == 0){
				// child

				// assign output of command to write end of output pipe
				bool lastElement = (it != commandTable.end()) && (it + 1 == commandTable.end());
				cout << "[" << cmd.commandName << "]" << " Child. Begin pipe: " << cmd.outputPipe[0] << "/" << cmd.outputPipe[1] << ". Last cmd: " << lastElement << endl;

				if (lastElement || cmd.outputFileName[0] != '\0'){
					std::cout << "In child3. " << cmd.commandName << endl;

					// this is the last command or outfile file isnt empty
					if(lastElement){
						// revert standard out
						// dup2(STDOUT_FILENO, 1);
						dup2(1, STDOUT_FILENO);
					}else{
						// TODO write to file
					}
				}else{
					std::cout << "Rerouting output to pipe write 1. " << cmd.commandName << endl;
					dup2(cmd.outputPipe[1], STDOUT_FILENO);
					std::cout << "Rerouting output to pipe write 2. " << cmd.commandName << endl;

				}
				cout << "[" << cmd.commandName << "]" << " Child. Begin pipe: " << cmd.outputPipe[0] << "/" << cmd.outputPipe[1] << endl;

				// assign input
				
				if(i > 0){
					// get previous command pipe
					std::cout << "Assigning INPUT from PREV [BEFORE] command: " << commandTable[i-1].outputPipe[0] << "/" << commandTable[i-1].outputPipe[1] << endl;
					// assign the input of this command to be the read end of the output pipe from previous command
					dup2(commandTable[i-1].outputPipe[0], STDIN_FILENO);
					std::cout << "Assigning INPUT from PREV [AFTER] command: " << commandTable[i-1].outputPipe[0] << "/" << commandTable[i-1].outputPipe[1] << endl;
				}


				close(cmd.outputPipe[0]);
				close(cmd.outputPipe[1]);

				cout << "[" << cmd.commandName << "]" << " Child. Begin pipe: " << cmd.outputPipe[0] << "/" << cmd.outputPipe[1] << endl;

				// execute command
				// generate argv
				std::cout << "Executing command1 " << cmd.commandName << endl;

				char cmdNameC[cmd.commandName.length()+1];
				strcpy(cmdNameC, cmd.commandName.c_str());
				std::cout << "Executing command2 " << cmd.commandName << endl;

				// create array of args
				//https://stackoverflow.com/questions/5797837/how-to-pass-a-vector-of-strings-to-execv
				const char **argv = new const char* [cmd.args.size()+2];
				argv[0] = cmdNameC;
				std::cout << "Executing command3 " << cmd.commandName << endl;

				for(int i = 0; i < cmd.args.size(); i++){
					argv[i+1] = cmd.args[i].c_str();
				}
				argv[cmd.args.size()+1] = NULL;
				std::cout << "Executing command 4" << cmd.commandName << endl;

				// https://man7.org/linux/man-pages/man3/exec.3.html
				// execv only returns on an error, and if there is an error, exit the child

				std::cout << "Executing command " << cmd.commandName << endl;
				if (execv(argv[0], (char **)argv) < 0){
					cout << "ERROR" << errno << endl;
					exit(0);
				}
			}

			validCommandCount += 1;
		}else{
			// found a command that is null, we are done with command table
			break;
		}
	}



	std::cout << "Waiting for all commands to finish " << validCommandCount << endl;
	// TODO handle the & and background processing. do that here (at the command level, race conditions between commands?)? or at the table level?
	int status;
	for (int i = 0; i < validCommandCount; i++)
		wait(&status);

	std::cout << "Closing all pipes" << endl;
	for(int i = 0; i < commandTable.size(); i++){
		command cmd = commandTable[i];
		close(cmd.outputPipe[0]);
		close(cmd.outputPipe[1]);
	}		

	// reset commandTable here
	return 0;
}

// http://www.rozmichelle.com/pipes-forks-dups/
