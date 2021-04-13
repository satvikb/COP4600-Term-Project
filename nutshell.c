// This is ONLY a demo micro-shell whose purpose is to illustrate the need for and how to handle nested alias substitutions and Flex start conditions.
// This is to help students learn these specific capabilities, the code is by far not a complete nutshell by any means.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "global.h"
#include <unistd.h>
#include <limits.h>
extern int yyparse (void);

char* getcwd(char *buf, size_t size);
void buildEnvs();
// char* getCurrentDirectory();
const char* getHomeDirectory();

int main()
{
    buildEnvs();

    system("clear");
    while(1)
    {
        printf("[%s]>> ", &envMap["PROMPT"][0]);
        yyparse();
    }

    return 0;
}

void buildEnvs(){
    char cwd[PATH_MAX]; // PATH_MAX = 4096
    getcwd(cwd, sizeof(cwd)); // put the current working directory into cwd
   
    envMap["PWD"] = cwd;
    envMap["PATH"] = ".:/bin:/usr/bin";
    envMap["HOME"] = getHomeDirectory();
    envMap["PROMPT"] = "nutshell-sb-rr";
}

// char* getCurrentDirectory(){
//      return &cwd[0];
// }

// https://stackoverflow.com/questions/2910377/get-home-directory-in-linux
const char* getHomeDirectory(){
    const char *homedir;
    if ((homedir = getenv("HOME")) == NULL) {
        homedir = getpwuid(getuid())->pw_dir;
    }
    return homedir;
}

void updateParentDirectories(string path){
    cout << "UPDATING PARENT " << path << endl;
    // http://www.cplusplus.com/reference/string/string/find_last_of/
    size_t found = path.find_last_of("/\\");
    string parent = path.substr(0,found);

    aliasMap["."] = path;
    aliasMap[".."] = parent;
}