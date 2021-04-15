%{
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

int yylex(); 
int yyerror(char *s);
void errorMessage(string e);

int runCD(string charArg);
string removeParent(string path);

string getFolderOfFile(string path);
string getFileOfFolder(string path);

bool checkIfWordEndsAtName(char *name, char *word);
int runSetAlias(char *name, char *word);
int runPrintAlias();
void unsetAlias(char* name);

int runSetEnv(char *variable, char *word);
int runPrintVariable();
void unsetVariable(char* variable);

int runCommandTable(bool appendOutput, bool redirectStdErr, bool stdErrToStdOut, string errFileOutput);
int runCommandTableInBackground(bool appendOutput, bool redirectStdErr, bool stdErrToStdOut, string errFileOutput);
void printFileName(int fd);

%}

%union {
		int val;
		char *string;
		struct list* arguments;
		struct pipedCmds* commands;
		struct outputFileCmd* output;
		struct errorOutput* error;
	}

%start cmd_line

%token <string> BYE CD STRING ALIAS UNALIAS SETENV UNSETENV PRINTENV END CUSTOM_CMD ERROR_FILE ERROR_OUTPUT BACKGROUND
// misc tokens
%token <string> ESC EOFEND PIPE IN OUT A_OUT

%nterm <string> redirectable_cmd
%nterm <arguments> arg_list
%nterm <commands> piped_cmd_list
%nterm <string> input_file
%nterm <output> output_file
%nterm <error> error_output
%nterm <val> background


%%
cmd_line    	:
	BYE END 		                									{exit(1); return 1; }
	| EOFEND															{exit(1); return 1; }
	| CD END															{runCD(""); return 1;}
	| CD STRING END        												{runCD($2); return 1;}
	| SETENV STRING STRING END											{runSetEnv($2, $3); return 1;}
	| UNSETENV STRING END												{unsetVariable($2); return 1;}
	// | PRINTENV END														{runPrintVariable(); return 1;}
	| ALIAS STRING STRING END											{runSetAlias($2, $3); return 1;}
	//| ALIAS END														{runPrintAlias(); return 1;}
	| UNALIAS STRING END												{unsetAlias($2); return 1;}
	| redirectable_cmd arg_list piped_cmd_list input_file output_file error_output background END	{																		
		string errorOutputFile = "";
		bool appendOutput = false;
		bool redirectStdError = false;
		bool errorToStout = false;

		if($5 != NULL && $5->append == 1) {
			appendOutput = true;	
		} 

		if($6 != NULL) {
			redirectStdError = true;
			errorOutputFile = $6->fileName;
			if($6->toFile == 0) {
				errorToStout = true;
			}
		}

		delete $6;

		vector<string> mainArgs;
		for(int i = 0; i < ($2)->size; i++) {
			mainArgs.push_back($2->args[i]);
		}
		//free($2->args);
		//delete $2;
		command mainCommand;
		mainCommand.commandName = $1;
		mainCommand.args = mainArgs;

		if($4 != NULL){
			string inputFileName($4);
			mainCommand.inputFileName = inputFileName;					
		}
		
		if($3->commands.size() == 0 && $5 != NULL) {
			mainCommand.outputFileName = $5->fileName;
		}

		
		commandTable.push_back(mainCommand);

		for(int i = 0; i < $3->commands.size(); i++) {
			command cmd;
			cmd.commandName = $3->commands[i]->name;
			//printf("%s\n",  $3->commands[i]->name);

			vector<string> args;
			for(int j = 0; j < $3->commands[i]->args->size; j++) {
				args.push_back($3->commands[i]->args->args[j]);
			}
			//delete $3->commands[i]->args;
			//delete $3->commands[i];

			cmd.args = args;

			if(i == $3->commands.size() - 1 && $5 != NULL) {
				cmd.outputFileName = $5->fileName;
			}

			commandTable.push_back(cmd);
			
		}

		delete $3;
		delete $5;
		
		if($7 == 0) {
			runCommandTable(appendOutput, redirectStdError, errorToStout, errorOutputFile);
		} else {
			runCommandTableInBackground(appendOutput, redirectStdError, errorToStout, errorOutputFile);
		}
		return 1;
	}
	| error	END						{cout << endl << endl << "The following command was not found: " << $2 << endl << "Please check your spelling." << endl << endl; return 1;}

redirectable_cmd	:
	CUSTOM_CMD						{strcpy($$, $1);}
	| PRINTENV						{strcpy($$, "printenv");}
	| ALIAS							{strcpy($$, "alias");}

arg_list    		:
	%empty							{$$ = newArgList();}
	| arg_list STRING               {$$ = $1; strcpy($$->args[$$->size], $2); $$->size++;}

piped_cmd_list 		:
 	%empty												{$$ = newPipedCmdList();}
 	| piped_cmd_list PIPE redirectable_cmd arg_list	{$$ = $1; $$ = appendToCmdList($1, $3, $4);}

input_file			:
	%empty							{ $$ = NULL; }
	| IN STRING						{ $$ = $2; }

output_file :
	%empty							{ $$ = NULL; }
	| OUT STRING					{ $$ = new outputFileCmd(); $$->fileName = $2; $$->append = 0; }
	| A_OUT STRING					{ $$ = new outputFileCmd(); $$->fileName = $2; $$->append = 1; }

error_output :
	%empty 							{ $$ = NULL; }
	| ERROR_FILE STRING             { $$ = new errorOutput(); $$->fileName = $2; $$->toFile = 1; }
	| ERROR_OUTPUT           		{ $$ = new errorOutput(); $$->fileName = ""; $$->toFile = 0; }

background   :
	%empty							{ $$ = 0; }
	| BACKGROUND					{ $$ = 1; }
%%

int yyerror(char *s) {
//   printf("The command was not found\n");
  return 0;
}

void errorMessage(string e){
	cout << endl << endl;
	cout << e;
	cout << endl << endl;
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
// cd testdir/../..
int runCD(string charArg){
	// cout << "CDDD>>>" << endl;
	string arg = expandDirectory(charArg);
	

	if(chdir(arg.c_str()) == 0){ // change dir
		envMap["PWD"] = arg;
		updateParentDirectories(arg);
	} else {
		printf("cd: Directory not found\n");
		return 1;
	}
	
	return 1;
}

string expandDirectory(string arg){
	if(arg.empty()){
		arg = getHomeDirectory();
	}
	// remove / at the end of path if present (is this optional?)
	if(arg.back() == '/'){
		arg.pop_back();
	}
	if (arg[0] != '/') { // arg is relative path
		if(arg[0] == '.' && arg.size() > 1 && arg[1] == '/'){ // prevent just .. as .
			arg = CURRENT_DIR + arg.substr(1);
		}else if(arg[0] == '.' && arg.size() == 1){
			// just a .
			arg = CURRENT_DIR;
		}else{
			arg = CURRENT_DIR+"/"+arg;
		}
	}

	// cout << "ABSOLUTE PATH" << arg << endl;
	// find the first .. and do recursive expansion
	size_t foundDotDot = arg.find("..");
	while (foundDotDot != std::string::npos){
		string removingParentOn = arg.substr(0, foundDotDot+2);
		string newPrefix = removeParent(removingParentOn);
		arg = newPrefix + arg.substr(foundDotDot+2);
		foundDotDot = arg.find("..");
	}
	return arg;
}

string completeString(string partial){
	if(partial[0] == '~'){
		auto i = FindPrefix(systemUsers, partial.substr(1));
		if (i != systemUsers.end()){
			cout << 'Found: \t' << i->first << ", " << i->second;
			return i->second;
		}
	}else{
		string fullPath = expandDirectory(partial);
		string dirStr = getFolderOfFile(fullPath);
		string fileName = getFileOfFolder(fullPath); // do it this way to take into account ../../fil	(esc)
		string matchString = strcat(&fileName[0], "*");
		cout << "Completing String " << partial.size() << "___" << fullPath << "____" << fileName << "____" << matchString << endl;

 		DIR* d;
		struct dirent *dir;
		d = opendir(dirStr.c_str());
		while((dir = readdir(d)) != NULL) {
			if(fnmatch(&matchString[0], dir->d_name, 0) == 0) {
				string matched(dir->d_name);
				closedir(d);
				cout << "Found " << dirStr << "_Match: " << matched << endl;
				string fullMatched = dirStr+"/"+matched;
				// return fullMatched; // return this if yyput replaces everything before until space (need the whole path)
				return matched; // return this if yyput only replaces the file name (not including / and ..)
			}
		}
		closedir(d);
	}
	return partial;
}

// input - path with .. being the last thing in the string
/*
	ex input:
	path/rel/to/..
	/abs/path/to/..

	output:
	path/rel/
	/abs/path/
*/

// output - actual path
string removeParent(string path){
	size_t found = path.rfind("..");
	if (found != std::string::npos){
		size_t foundSlash = path.substr(0, found-1).find_last_of("/\\");
		string parent = path.substr(0,foundSlash);
		path = parent;
		// need?
		if(path.back() == '/'){
			path.pop_back();
		}
		return path;
	}else{
		// .. not found
		return path;
	}
}


string getFolderOfFile(string path){
	size_t found = path.find_last_of("/\\");
	if(found != string::npos){
		return path.substr(0,found);
	}
	return path;
}

string getFileOfFolder(string path){
	size_t found = path.find_last_of("/\\");
	if(found != string::npos){
		return path.substr(found+1);
	}
	return path;
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

	return 1;
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

	return 1;
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

void printFileName(int fd){
	enum { BUFFERSIZE = 1024 };
	char buf1[BUFFERSIZE];
	string path = "/proc/self/fd/";
	path += std::to_string(fd);
	ssize_t len1 = readlink(path.c_str(), buf1, sizeof(buf1));
	if (len1 != -1) {buf1[len1] = '\0';}
	cout << buf1;
}

int runCommandTableInBackground(bool appendOutput, bool redirectStdErr, bool stdErrToStdOut, string errFileOutput){
	if(fork() == 0){
		cout << "RUNNING IN BG" << endl;
		runCommandTable(appendOutput, redirectStdErr, stdErrToStdOut, errFileOutput);
		exit(0);
	}
	return 0;
}

// ASSUMPTION: a command can only do one of either Output to file or Redirect into pipe, Not both.
// ^ so a command must end with | or > (if not using &1)

// ASSUMPTION: any command/multiple commands can have input files with <.
// ^ the spec however, only shows one < at the end of the line?
int runCommandTable(bool appendOutput, bool redirectStdErr, bool stdErrToStdOut, string errFileOutput){
		// cout << "RUNNING " << commandTable.size() << " commands" << endl;
	// fflush(stdout);
	// printf("\x1B[A"); // move up one
	// printf("\n"); // make new line

	int pipes[commandTable.size()-1][2];

	int saved_stdout = dup(STDOUT_FILENO);
	int saved_stdin = dup(STDIN_FILENO);
	int saved_stderr = dup(STDERR_FILENO);

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
		// cout << i << ": " << cmd.commandName << endl;

		// for(int k = 0; k < cmd.args.size(); k++){
		// 	cout << "A: " << cmd.args[k] << endl;
		// }

		pipe(pipes[i]);
	}
	
	// 3rd loop - execute commands, deal with actual files here
	for(int i = 0; i < validCommandCount; i++){
		command cmd = commandTable[i];
		// cout << cmd.commandName << endl;

		if(fork() == 0){
			// execute command
			// generate argv
			dup2(saved_stdout, STDOUT_FILENO);
			dup2(saved_stdin, STDIN_FILENO);
			dup2(saved_stderr, STDERR_FILENO);


			

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
			
			// handle input
			if(firstCommand && !cmd.inputFileName.empty()){
				// cout << "READING INPUT" << endl;
				// https://linuxhint.com/dup2_system_call_c/
				int inputFd = open(&cmd.inputFileName[0], O_RDONLY);
				if(dup2(inputFd, STDIN_FILENO) < 0){
					// err
				}

			}

			if(firstCommand && !lastCommand){
				// cout << "FIRST COMMAND " << cmd.commandName << endl;
				// only assign stdout to write to pipe
				dup2(pipes[0][INPUT_END], STDOUT_FILENO);
				close(pipes[0][INPUT_END]);
				// input stays stdin
				// dup2(saved_stdin, STDIN_FILENO);
			}
			
			if(!(firstCommand || lastCommand)){
				// cout << "middle " << cmd.commandName << endl;
				// input is output end pipe from previous command
				if(dup2(pipes[i-1][OUTPUT_END], STDIN_FILENO) < 0){
					cout << "ERROR" << endl;
				}
				close(pipes[i-1][OUTPUT_END]);
				// output is write end of this pipe
				if(dup2(pipes[i][INPUT_END], STDOUT_FILENO) < 0){
					// perror("Err ");
					cout << "ERROR2" << endl;
				}
				close(pipes[i][INPUT_END]);

				// REMEMBER THIS DOES NOT RUN IN TWO COMMAND CONFIG
				// middle command
				// cout << "Middle " << cmd.commandName << endl;
			}
			
			if(lastCommand && !firstCommand){
				// cout << "LAast " << cmd.commandName << endl;
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
				// cout << "OUTPUT FILE" << endl;
				int flags;
				if(appendOutput){
					flags = O_RDWR|O_CREAT|O_APPEND;
				}else{
					flags = O_RDWR|O_CREAT;
				}
				int out = open(&cmd.outputFileName[0], flags, 0600);
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

			if(redirectStdErr){
				if(stdErrToStdOut){
					dup2(STDOUT_FILENO, STDERR_FILENO);
				}else{
					// output to file
					int	flags = O_RDWR|O_CREAT|O_APPEND;
					int out = open(&errFileOutput[0], flags, 0600);
					if (-1 == out) { 
						perror("error opening error output file"); 
						return 255; 
					}

					dup2(out, STDERR_FILENO);
					// TODO it works with and without this, keep?
					fflush(stderr);
					close(out);
				}
			}


			// TODO need to restore stdin, out and err? it is also done in parent
			close(saved_stdout);
			close(saved_stdin);
			close(saved_stdin);
			for(int k = 0; k < sizeof(pipes) / sizeof(pipes[0]); k++){
				close(pipes[k][OUTPUT_END]);
				close(pipes[k][INPUT_END]);
			}

			// cout << "Running " << cmd.commandName << ". Input from: ";
			// printFileName(STDIN_FILENO);
			// cout << ". Output to: ";
			// printFileName(STDOUT_FILENO);
			// cout << endl;

			if(cmd.commandName == "alias"){
				runPrintAlias();
				exit(0);
			}else if(cmd.commandName == "printenv"){
				runPrintVariable();
				exit(0);
			}else{
				if (execv(argv[0], (char **)argv) < 0){
					cout << "ERROR" << errno << endl;
					// TODO purge command here and go to next input, maybe ensure all pipes are closed
					exit(0);
				}
			}
			
		}
	}

	for(int k = 0; k < sizeof(pipes) / sizeof(pipes[0]); k++){
		close(pipes[k][OUTPUT_END]);
		close(pipes[k][INPUT_END]);
	}


	// cout << "waiting  " << endl;
	// TODO handle the & and background processing. do that here (at the command level, race conditions between commands?)? or at the table level?
	int status;
	for (int i = 0; i < validCommandCount; i++)
		wait(&status);

	// put everything back. is this needed?
	dup2(saved_stdout, STDOUT_FILENO);
	dup2(saved_stdin, STDIN_FILENO);
	dup2(saved_stderr, STDERR_FILENO);

	fflush(stdout);
	fflush(stderr);

	close(saved_stdout);
	close(saved_stdin);
	// reset commandTable here
	// TODO this doesnt work? might only be when outputting to file?
	commandTable.clear();

	return 0;
}

// http://www.rozmichelle.com/pipes-forks-dups/
