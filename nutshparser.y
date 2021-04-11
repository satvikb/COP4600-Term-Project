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

int yylex(); 
int yyerror(char *s);
int runCD(char* arg);

bool checkIfWordEndsAtName(char *name, char *word);
int runSetAlias(char *name, char *word);

int runSetEnv(char *variable, char *word);
int runCommand(struct commandpipe entry);
%}

%union {char *string;}

%start cmd_line
%token <string> BYE CD STRING ALIAS SETENV END

%%
cmd_line    :
	BYE END 		                {exit(1); return 1; }
	| CD STRING END        			{runCD($2); return 1;}
	| SETENV STRING STRING END		{runSetEnv($2, $3); return 1;}
	| ALIAS STRING STRING END		{runSetAlias($2, $3); return 1;}
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

}

// ASSUMPTION: a command can only do one of either Output to file or Redirect into pipe, Not both.
// ^ so a command must end with | or > (if not using &1)

// ASSUMPTION: any command/multiple commands can have input files with <.
// ^ the spec however, only shows one < at the end of the line?
int runCommandTable(struct command commandTable[]){
	// loop through command table
	/*
	example:
			sort < colors.txt | uniq -c | sort -r | head -3 > favcolors.txt

			commandTable[0] = {CMD: sort, # arg: 0, args: nullptr, inputFileName: colors.txt, outputFile: null}
			commandTable[1] = {CMD: uniq, # arg: 1, args: [-c](?), input: null, output: null}
			commandTable[2] = {CMD: sort, # arg: 1, args: [-r](?), input: null, output: null}
			commandTable[3] = {CMD: head, # arg: 1, args: [-3](?), input: null, outputFileName: favcolors.txt}

	*/
	/*
		loop:
			setup input output between commands in command table
			^ i/o should only ever be from previous or next command

			Create commandpipe struct:
				test if input file exists:
					yes: pipe to it
					no: pipe to standard input
				// TODO also deal with 2>&1 (maybe this should be dealt with outside the loop at the end)
				test if output file exists: 
					yes: output pipe to it
					no: &1
			runCommand(commandpipe)
	*/

	// https://stackoverflow.com/questions/18914960/how-to-iterate-over-of-an-array-of-structures/18914961
	struct command *ptr = commandTable;

	// maybe use a pipe system outside the loop to facilitate data transfer?
	/*
		OUTPUT OF CURRENT COMMAND:
		curOut[0] - read end of current command output (current command -> next command), 
		curOut[1] - write end, input (current command -> next command)

		INPUT TO CURRENT COMMAND:
		curIn[0] - read end of current command output (prev command -> current command), 
		curIn[1] - write end, input (current command -> next command)
	*/

	int cutIn[2];
	int curOut[2];
	int tmp[2];

	// init pipes
	pipe(curIn);
	pipe(curOut);
	pipe(tmp);

	// defaults
	// assign standard input into write end of input pipe to command
	// dup2(STDIN_FILENO, curIn[1]); // redundant when using tmp
	// assign standard output into write end of output pipe from command
	dup2(STDOUT_FILENO, curOut[1]);

	dup2(STDIN_FILENO, tmp[1]);

	for(int i = 0; i < 32 - 1/*lenCommandTable*/; i++, ptr++){
		if(ptr->commandName[0] != '\0'){
			struct commandpipe cmdPipe;
			
			strcpy(cmdPipe.commandName, ptr->commandName);
			cmdPipe.numberArguments = ptr->numberArguments;
			strcpy(cmdPipe.args, ptr->args);

			// ASSIGN INPUT TO COMMAND
			// 1 - assign output (read end) of tmp into input write end. (data written to tmp[1] is from previous command or stdin)
			// 2 - check if Input file name exists, if it does READ IN INPUT
				// read file: pretty much write equivalent of dup2(fileNameFd, curIn[1]);
			// DNE: leave input as is (either default stdin, or assigned by previous iteration)

			// ASSIGN OUTPUT FROM COMMAND
			// 3 - check if next command in table exists
				// next command exists: assign curOut[0] to tmp[1] ( dup2(curOut[0], tmp[1]) ) (route output of this command into next)
			// DNE: leave output

			// run the command with cutIn and curOut
			// *outputPipe[0] // THE READ END OF THE OUTPUT, THIS IS WHAT GOES TO NEXT COMMAND*


			// implementation of above:
			dup2(tmp[0], curIn[1]); // 1
			if(ptr->inputFileName[0] != '\0'){ // 2 - check if input file is not null
				// open file, write data to pipe. maybe wait to write until command starts running
				// to prevent buffer limit / deadlock?

			}

			// assuming ptr++ is equivalent to ptr = ptr + 1, then get next element in table
			if((ptr+1)->commandName[0] != '\0'){
				dup2(curOut[0], tmp[1]);
			}

			// run before close to prevent deadlock
			runCommand(cmdPipe, curIn, curOut);


			close(cutIn[0]);
			close(cutIn[1]);
			close(curOut[0]);
			close(curOut[1]);


		}else{
			// found a command that is null, we are done with command table
			break;
		}
	}

	int status;
  	pid_t wpid = waitpid(pid, &status, 0); 

	// reset commandTable here
}

// recursive call, maybe need to pass in other fds from the runCommandTable function?
// http://www.rozmichelle.com/pipes-forks-dups/

// create child to run the process
// function assumes inputPipe and outputPipe are already created
// inputPipe and outputPipe are NOT NULL, they will either be pipe fd or 0,1,2
int runCommand(struct commandpipe entry, int inputPipe[], int outputPipe[]){
	char *cmdName = entry.commandName;
	int argCount = entry.numberArguments;
	char *args = entry.args;
	// int *inputPipe = entry.inputPipe;
	// int *outputPipe = entry.outputPipe;

	/*
		https://man7.org/linux/man-pages/man2/pipe.2.html

		inputPipe[0] - READ END
		inputPipe[1] - WRITE END
	*/

	// maybe change the output here?
	// maybe dup2 with outputpipe and stdout?


	// create child process
	// REMEMBER CHILD HAS EVERYTHING COPIED AT THIS POINT (INCLUDING STDIN AND STDOUT)
	// TODO TEST IF THE INPUTPIPE AND OUTPUT PIPE ALSO COPIES OVER OR IF JUST POINTERS.
	// NEED TO MAKE SURE IT COPIES AND ARE NOT JUST POINTERS... or do pointers even matter?
	pid_t pid = fork();
	if(pid == 0){
		// child
		/*
			so at this point, we have to make inputPipe[0] the input to the 
			process we are about to execute?

			REMEMBER EVERYTHING IN THIS IF STATEMENT IS IN THE CONTEXT OF THE CHILD
			THE READ END OF THE PIPE IS INPUT IN TERMS OF CHILD
		*/
		

		// assign the input of the new exec to be the read from the read end of the input pipe
		dup2(inputPipe[0], STDIN_FILENO);
		// assign the output of the new exec to be written to the write end of the output pipe
		dup2(outputPipe[1], STDOUT_FILENO);


		// so at this point inputPipe[0] is not needed since the readable end of the pipe
		// is associated with either stdin or the file(?)
		close(inputPipe[0]);
		// close the write end of the pipe in child
		close(inputPipe[1]);

		close(outputPipe[0]);
		close(outputPipe[1]);

		// run the command using execv (an array of args)

		// TODO use number of arguments and args string to create char *const argv[] for execv
		// build exec arg array
		// TODO with arguments
		char *argv[] = {cmdName, NULL};
		// https://man7.org/linux/man-pages/man3/exec.3.html
		// execv only returns on an error, and if there is an error, exit the child
		if (execv(argv[0], argv) < 0){
			exit(0);
		}
	}

	// parent only section

	// read end of pipe not used in parent
	// DONE IN PARENT FUNCTION
	// close(inputPipe[0]);


	// wait for child to exit.
	// TODO handle the & and background processing. do that here (at the command level, race conditions between commands?)? or at the table level?
	// int status;
  	// pid_t wpid = waitpid(pid, &status, 0); 
	return 0;
}