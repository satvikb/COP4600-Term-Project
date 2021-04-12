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

#define OUTPUT_END 0
#define INPUT_END 1

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
%token <string> BYE CD STRING ALIAS UNALIAS SETENV UNSETENV PRINTENV END CUSTOM_CMD EC
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
	| EC END						{runExampleCommand(); return 1;}
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
	commandTable.clear();
	command start = { .commandName = "/bin/ls"};
	command cat = { .commandName = "/bin/cat"};
	vector<string> catArgs; catArgs.push_back("Makefile");
	cat.args = catArgs;
	// cat.outputFileName = "testOut.txt";

	command grep = { .commandName = "/bin/grep"};
	vector<string> grepArgs; grepArgs.push_back("C");
	grep.args = grepArgs;
	grep.outputFileName = "testOut2.txt";

	commandTable.push_back(start);
	commandTable.push_back(cat);
	commandTable.push_back(grep);

	runCommandTable(commandTable);
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
		pipe(pipes[i]);
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
			
			if(firstCommand && !lastCommand){
				cout << "TO STDOUT" << endl;
				// only assign stdout to write to pipe
				dup2(pipes[i][INPUT_END], STDOUT_FILENO);
			}
			if(lastCommand && !firstCommand){
				dup2(STDOUT_FILENO, pipes[i][OUTPUT_END]);

				// stdin becomes output of previous pipe
				dup2(pipes[i-1][OUTPUT_END], STDIN_FILENO);

				// // dont like having a special case like this
				// if(validCommandCount <= 1){
				// 	// TODO it works without this?
				// 	// first and last command, make the read end of the pipe (for the same first cmd) the input to the command
				// 	dup2(pipes[0][OUTPUT_END], STDIN_FILENO);
				// }else{
				// 	dup2(pipes[i-1][OUTPUT_END], STDIN_FILENO);
				// }

			}
			if(!(firstCommand || lastCommand)){
				// REMEMBER THIS DOES NOT RUN IN TWO COMMAND CONFIG
				cout << "MIDDLE COMMAND " << cmd.commandName << endl;
				// middle command
				// assign stdin to be output from previous command
				dup2(pipes[i-1][OUTPUT_END], STDIN_FILENO);
				// assign cmd stdout to be current pipe write
				dup2(pipes[i][INPUT_END], STDOUT_FILENO);
			}
			if(lastCommand && !cmd.outputFileName.empty()){
				cout << "BACK TO STDOUT" << endl;
				cout << "OUTPUT TO FILE" << endl;

				// write to file https://stackoverflow.com/questions/8516823/redirecting-output-to-a-file-in-c
				int out = open(&cmd.outputFileName[0], O_RDWR|O_CREAT|O_APPEND, 0600);
				if (-1 == out) { 
					perror("error opening output file"); 
					return 255; 
				}

				// int save_out = dup(STDOUT_FILENO);

				dup2(out, STDOUT_FILENO);
				// dup2(out, pipes[i][OUTPUT_END]);
				// dup2(out, pipes[i][INPUT_END]);
				// dup2(pipes[i][INPUT_END], out);

				// fflush(stdout);
				close(out);

				// dup2(save_out, STDOUT_FILENO);
				// close(save_out);
			}

			if(lastCommand && !firstCommand){
				
				// because we close on i+1, close i on the last command
				close(pipes[i][OUTPUT_END]);
				close(pipes[i][INPUT_END]);
			}
			// wait until i+1 iteration to close pipes on the i iteration since we use pipes[i-1] above
			if(i > 0){
				close(pipes[i-1][OUTPUT_END]);
				close(pipes[i-1][INPUT_END]);
			}else if(validCommandCount == 1){
				close(pipes[i][OUTPUT_END]);
				close(pipes[i][INPUT_END]);
			}

			if (execv(argv[0], (char **)argv) < 0){
				cout << "ERROR" << errno << endl;
				// TODO purge command here and go to next input, maybe ensure all pipes are closed
				exit(0);
			}
		}
	}

	for(int i = 0; i < commandTable.size(); i++){
		command cmd = commandTable[i];
		close(pipes[i][OUTPUT_END]);
		close(pipes[i][INPUT_END]);
	}
	
	// TODO handle the & and background processing. do that here (at the command level, race conditions between commands?)? or at the table level?
	int status;
	for (int i = 0; i < validCommandCount; i++)
		wait(&status);
	
	// reset commandTable here
	// TODO this doesnt work? might only be when outputting to file?
	commandTable.clear();
	return 0;
}

// http://www.rozmichelle.com/pipes-forks-dups/
