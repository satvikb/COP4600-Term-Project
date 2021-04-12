// This is ONLY a demo micro-shell whose purpose is to illustrate the need for and how to handle nested alias substitutions and Flex start conditions.
// This is to help students learn these specific capabilities, the code is by far not a complete nutshell by any means.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "global.h"
#include <unistd.h>
#include <limits.h>
extern int yyparse (void);

char *getcwd(char *buf, size_t size);
void buildEnvs();

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
    char cwd[PATH_MAX];
    getcwd(cwd, sizeof(cwd)); // put the current working directory into cwd

    envMap["PWD"] = cwd;
    envMap["PATH"] = ".:/bin:/usr/bin";
    envMap["PROMPT"] = "nutshell-sb";
}
