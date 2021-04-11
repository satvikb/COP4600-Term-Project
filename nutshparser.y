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
int runSetAlias(char *name, char *word);
int runSetEnv(char *variable, char *word);
int runCommand(struct commandpipe entry);
%}

%union {char *string;}

%start cmd_line
%token <string> BYE CD STRING ALIAS UNALIAS SETENV UNSETENV PRINTENV END

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

	struct command *ptr = commandTable;
	for(int i = 0; i < 32/*lenCommandTable*/; i++, ptr++){
		struct commandpipe cmdPipe;

		strcpy(cmdPipe.commandName, ptr->commandName);
		cmdPipe.numberArguments = ptr->numberArguments;
		strcpy(cmdPipe.args, ptr->args);

		pipe(cmdPipe.inputPipe);
		
		// assign the input to the child
		// if there is an input file, we read from it and write into pipe

		if(ptr->inputFileName[0] != '\0'){
			// input file name is not empty
			// so we write into the write end (input) of the pipe for the child?

			// TODO change this to be input file data
			// https://man7.org/linux/man-pages/man3/dprintf.3p.html // https://linux.die.net/man/3/dprintf
			// write to input side of pipe for the child
			dprintf(cmdPipe.inputPipe[1], "This should be the file input\n"); 
		}else{
			// no input file. so this needs to be either no input or 
			// TODO: piped data from another command
		}

		// finishing writing data for child
		close(cmdPipe.inputPipe[1]);

		// it should be ok if we runCommand after closing pipe right? data should still exist in pipe?
		runCommand(cmdPipe);







	}


	// reset commandTable here
}

// recursive call, maybe need to pass in other fds from the runCommandTable function?
//http://www.rozmichelle.com/pipes-forks-dups/
int runCommand(struct commandpipe entry){
	char *cmdName = entry.commandName;
	int argCount = entry.numberArguments;
	char *args = entry.args;
	int *inputPipe = entry.inputPipe;
	int *outputPipe = entry.outputPipe;

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
		

		// read end of pipe will assigned be standard input of child? yes, the write end will be from parent
		// https://man7.org/linux/man-pages/man2/dup2.2.html
		dup2(inputPipe[0], STDIN_FILENO);

		// so at this point inputPipe[0] is not needed since the readable end of the pipe
		// is associated with either stdin or the file(?)
		close(inputPipe[0]);
		// close the write end of the pipe in child
		close(inputPipe[1]);

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
	close(inputPipe[0]);


	// wait for child to exit.
	// TODO handle the & and background processing. do that here (at the command level, race conditions between commands?)? or at the table level?
	int status;
  	pid_t wpid = waitpid(pid, &status, 0); 
	return 0;
}