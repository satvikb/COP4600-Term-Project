// This is ONLY a demo micro-shell whose purpose is to illustrate the need for and how to handle nested alias substitutions and Flex start conditions.
// This is to help students learn these specific capabilities, the code is by far not a complete nutshell by any means.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "global.h"
#include <unistd.h>
#include <limits.h>
char *getcwd(char *buf, size_t size);

int main()
{
    aliasIndex = 0;
    varIndex = 0;
    char cwd[PATH_MAX];
    getcwd(cwd, sizeof(cwd)); // put the current working directory into cwd

    strcpy(varTable.var[varIndex], "PWD"); // varIndex = 0
    strcpy(varTable.word[varIndex], cwd);
    varIndex++;
    strcpy(varTable.var[varIndex], "HOME"); // varIndex = 1
    strcpy(varTable.word[varIndex], cwd);
    varIndex++;
    strcpy(varTable.var[varIndex], "PROMPT"); // varIndex = 2
    strcpy(varTable.word[varIndex], "nutshell-sb");
    varIndex++;
    strcpy(varTable.var[varIndex], "PATH"); // varIndex = 3
    strcpy(varTable.word[varIndex], ".:/bin");
    varIndex++;

    strcpy(aliasTable.name[aliasIndex], "."); // aliasIndex = 0
    strcpy(aliasTable.word[aliasIndex], cwd);
    aliasIndex++;

    char *pointer = strrchr(cwd, '/');
    while(*pointer != '\0') {
        *pointer ='\0';
        pointer++;
    }
    strcpy(aliasTable.name[aliasIndex], "..");  // aliasIndex = 1
    strcpy(aliasTable.word[aliasIndex], cwd);
    aliasIndex++;

    system("clear");
    while(1)
    {
        printf("[%s]>> ", varTable.word[2]);
        yyparse();
    }

    return 0;
}
