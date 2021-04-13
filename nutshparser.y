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
void printFileName(int fd);
%}

%union {
		char *string;
		struct list* arguments;
		struct pipedCmds* commands;
	}

%start cmd_line

%token <string> BYE CD STRING ALIAS UNALIAS SETENV UNSETENV PRINTENV END CUSTOM_CMD EC PIPE IN OUT A_OUT
// %token PIPE "|"
// %token IN "<"
// %token OUT ">"
// %token A_OUT ">>"


%nterm <string> redirectable_cmd
%nterm <arguments> arg_list
%nterm <commands> piped_cmd_list

%%
cmd_line    	:
	BYE END 		                									{exit(1); return 1; }
	| CD STRING END        												{runCD($2); return 1;}
	| SETENV STRING STRING END											{runSetEnv($2, $3); return 1;}
	| UNSETENV STRING END												{unsetVariable($2); return 1;}
	| PRINTENV END														{runPrintVariable(); return 1;}
	//| ALIAS STRING STRING END											{runSetAlias($2, $3); return 1;}
	//| ALIAS END															{runPrintAlias(); return 1;}
	| UNALIAS STRING END												{unsetAlias($2); return 1;}
	| EC END	{runExampleCommand(); return 1;}
	| redirectable_cmd arg_list piped_cmd_list END						{
																			// printf("%s\n", $1); 
																			// printf("%s\n", "Main Cmd Arguments");
																			// for(int i = 0; i < ($2)->size; i++) {
																			// 	printf("%s\t", $2->args[i]);
																			// }
																			// printf("\n");

																			// printf("%s\n", "Nested Commands");

																			// for(int i = 0; i < $3->commands.size(); i++) {
																			// 	printf("%s\t", $3->commands[i]->name);
																			// 	printf("\n");
																			// 	for(int j = 0; j < $3->commands[i]->args->size; j++) {
																			// 		printf("%s\t", $3->commands[i]->args->args[j]);
																			// 	}
																			// }
																			// printf("\n");

																			
																			
																			return 1;
																		}

redirectable_cmd	:
	CUSTOM_CMD						{$$ = $1;}
	| PRINTENV						{strcpy($$, "printenv");}
	| ALIAS							{strcpy($$, "alias");}

arg_list    		:
	%empty							{$$ = newArgList();}
	| arg_list STRING               {$$ = $1; strcpy($$->args[$$->size], $2); $$->size++;}

piped_cmd_list 		:
 	%empty												{$$ = newPipedCmdList();}
 	| piped_cmd_list PIPE redirectable_cmd arg_list	{$$ = $1; $$ = appendToCmdList($$, $3, $4);}
%%

int yyerror(char *s) {
  printf("%s\n",s);
  return 0;
}

list* newArgList() {
	list* l = new list();
	return l;
}



pipedCmds* newPipedCmdList() {
	pipedCmds* p = new pipedCmds();
	return p;
}

pipedCmds* appendToCmdList(pipedCmds* p, char* name, list* args) {
	nestedCmd* cmd = new nestedCmd();

	strcpy(cmd->name, name);
	cmd->args = args;

	p->commands.push_back(cmd);

	return p;
}

// TODO deal with CD command ending in /
// cd ../..
int runCD(char* arg) {
	if (arg[0] != '/') { // arg is relative path
		cout << "RELATIVE PATH" << endl;
		// add a / to the current path
		// append the arg to the current path + /
		string newPath = envMap["PWD"]+"/"+arg;

		// if error, shouldnt varTable.word[0] be reset to before concat?
		if(chdir(newPath.c_str()) == 0) {  // change working directory
			envMap["PWD"] = newPath;
			updateParentDirectories(newPath);
		}else {
			//strcpy(varTable.word[0], varTable.word[0]); // fix
			printf("Directory not found\n");
			return 1;
		}
	}else { // arg is absolute path
		if(chdir(arg) == 0){ // change dir
			envMap["PWD"] = arg;
			updateParentDirectories(arg);
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
	if(strcmp(variable, "HOME") == 0){
		cout << "Cannot unset HOME variable" << endl;
		return;
	}
	if(strcmp(variable, "PATH") == 0){
		cout << "Cannot unset PATH variable" << endl;
		return;
	}
	envMap.erase(variable);
}

void runPrintCurrentDirectory(){
	cout << envMap["PWD"] << endl;
}

void runExampleCommand(){
	commandTable.clear();
	// command start = { .commandName = "/bin/ls"};
	// command cat = { .commandName = "/bin/cat"};
	// vector<string> catArgs; catArgs.push_back("Makefile");
	// cat.args = catArgs;
	// // cat.outputFileName = "testOut.txt";

	// command grep = { .commandName = "/bin/grep"};
	// vector<string> grepArgs; grepArgs.push_back("txt");
	// grep.args = grepArgs;
	// // grep.outputFileName = "testOut2.txt";

	// commandTable.push_back(start);
	// // commandTable.push_back(cat);
	// commandTable.push_back(grep); // if only command is grep, it hangs. this is expected.

	// runCommandTable(commandTable);
	// return;

	// ls -l | grep "txt" | sort -n | tail-5 | rev | head-2| less
	command ls = { .commandName = "/bin/ls"};
	vector<string> arg1; arg1.push_back("-l");
	ls.args = arg1;

	command grep = { .commandName = "/bin/grep"};
	vector<string> arg2; arg2.push_back("c");
	grep.args = arg2;

	command sort = { .commandName = "/usr/bin/sort"};
	vector<string> arg3; arg3.push_back("-n");
	sort.args = arg3;

	command tail = { .commandName = "/bin/tail"};
	vector<string> arg4; arg4.push_back("-2");
	tail.args = arg4;
	tail.outputFileName = "testOut3.txt";

	command rev = { .commandName = "/bin/rev"};

	command head = { .commandName = "/bin/head"};
	vector<string> arg5; arg5.push_back("-2");
	head.args = arg5;

	command less = { .commandName = "/bin/head"};

	commandTable.push_back(ls);
	commandTable.push_back(grep);
	commandTable.push_back(sort);
	commandTable.push_back(tail);
	// commandTable.push_back(rev);
	// commandTable.push_back(less);
	runCommandTable(commandTable);
}

void printFileName(int fd){
	enum { BUFFERSIZE = 1024 };
	char buf1[BUFFERSIZE];
	string path = "/proc/self/fd/";
	path += std::to_string(fd);
	ssize_t len1 = readlink(path.c_str(), buf1, sizeof(buf1));
	if (len1 != -1) {buf1[len1] = '\0';}
	cout << buf1;
}

// ASSUMPTION: a command can only do one of either Output to file or Redirect into pipe, Not both.
// ^ so a command must end with | or > (if not using &1)

// ASSUMPTION: any command/multiple commands can have input files with <.
// ^ the spec however, only shows one < at the end of the line?
int runCommandTable(struct vector<command> commandTable){
	int pipes[commandTable.size()-1][2];

	int saved_stdout = dup(STDOUT_FILENO);
	int saved_stdin = dup(STDIN_FILENO);

	/*
		pipes = 
		[
			Output pipe for 1: [5,6]
			Output pipe for 2: [9,10]
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
		cout << cmd.commandName << endl;

		if(fork() == 0){
			// execute command
			// generate argv
			dup2(saved_stdout, STDOUT_FILENO);
			dup2(saved_stdin, STDIN_FILENO);


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
				cout << "FIRST COMMAND " << cmd.commandName << endl;
				// only assign stdout to write to pipe
				dup2(pipes[0][INPUT_END], STDOUT_FILENO);
				close(pipes[0][INPUT_END]);
				// input stays stdin
				dup2(saved_stdin, STDIN_FILENO);
			}
			
			if(!(firstCommand || lastCommand)){
				cout << "middle " << cmd.commandName << endl;
				// input is output end pipe from previous command
				if(dup2(pipes[i-1][OUTPUT_END], STDIN_FILENO) < 0){
					cout << "ERROR" << endl;
				}
				close(pipes[i-1][OUTPUT_END]);
				// output is write end of this pipe
				if(dup2(pipes[i][INPUT_END], STDOUT_FILENO) < 0){
					cout << "ERROR2" << endl;
				}
				close(pipes[i][INPUT_END]);

				// REMEMBER THIS DOES NOT RUN IN TWO COMMAND CONFIG
				// middle command
				cout << "Middle " << cmd.commandName << endl;
			}
			
			if(lastCommand && !firstCommand){
				cout << "LAast " << cmd.commandName << endl;
				// output is stdout
				dup2(saved_stdout, STDOUT_FILENO);
				// input is output from previous command
				dup2(pipes[i-1][OUTPUT_END], STDIN_FILENO);
				close(pipes[i-1][OUTPUT_END]);

				// assign pipe output to STDOUT, then stdout either goes to file or just left alone
				// dup2(STDOUT_FILENO, pipes[i][OUTPUT_END]);
				// // stdin becomes output of previous pipe
				// dup2(pipes[i-1][OUTPUT_END], STDIN_FILENO);
			}
			if(lastCommand && !cmd.outputFileName.empty()){
				// write to file https://stackoverflow.com/questions/8516823/redirecting-output-to-a-file-in-c
				cout << "OUTPUT FILE" << endl;
				int out = open(&cmd.outputFileName[0], O_RDWR|O_CREAT|O_APPEND, 0600);
				if (-1 == out) { 
					perror("error opening output file"); 
					return 255; 
				}

				dup2(out, STDOUT_FILENO);
				// TODO it works with and without this, keep?
				fflush(stdout);
				close(out);
			}

			// if(lastCommand && !firstCommand){
			// 	// because we close on i+1, close i on the last command
			// 	cout << "closing" << endl;
			// 	close(pipes[i][OUTPUT_END]);
			// 	close(pipes[i][INPUT_END]);
			// }
			// // wait until i+1 iteration to close pipes on the i iteration since we use pipes[i-1] above
			// if(i > 0){
			// 	close(pipes[i-1][OUTPUT_END]);
			// 	// close(pipes[i-1][INPUT_END]);
			// }else if(validCommandCount == 1){
			// 	// if only one command, above was changed such that no pipes are used. close them
			// 	// close(pipes[i][OUTPUT_END]);
			// 	close(pipes[i][INPUT_END]);
			// }
			close(saved_stdout);
			close(saved_stdin);
			for(int k = 0; k < sizeof(pipes) / sizeof(pipes[0]); k++){
				close(pipes[k][OUTPUT_END]);
				close(pipes[k][INPUT_END]);
			}

			cout << "Running " << cmd.commandName << ". Input from: ";
			printFileName(STDIN_FILENO);
			cout << ". Output to: ";
			printFileName(STDOUT_FILENO);
			cout << endl;

			if (execv(argv[0], (char **)argv) < 0){
				cout << "ERROR" << errno << endl;
				// TODO purge command here and go to next input, maybe ensure all pipes are closed
				exit(0);
			}
		}
	}

	for(int k = 0; k < sizeof(pipes) / sizeof(pipes[0]); k++){
		close(pipes[k][OUTPUT_END]);
		close(pipes[k][INPUT_END]);
	}

	close(saved_stdout);
	close(saved_stdin);
	cout << "waiting  " << endl;
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
