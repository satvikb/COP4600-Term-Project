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
void getSystemUsers();
void updatePrompt(string folderName);

// char* getCurrentDirectory();

int main()
{
    buildEnvs();
    system("clear");
    getSystemUsers();
    while(1)
    {
        printf("%s$ ", &envMap["PROMPT"][0]);
        yyparse();
    }

    return 0;
}

void buildEnvs(){
    struct passwd *p = getpwuid(getuid());
    char prefix[128] = "nutshell-";
    strcat(prefix, p->pw_name);
    //printf("User name: %s\n", p->pw_name);


    char cwd[PATH_MAX]; // PATH_MAX = 4096
    getcwd(cwd, sizeof(cwd)); // put the current working directory into cwd
   
    const char* homeDir = getHomeDirectory();

    envMap["PWD"] = cwd;
    envMap["PATH"] = ".:/bin:/usr/bin";
    envMap["HOME"] = homeDir;
    updateParentDirectories(cwd);
}

void getSystemUsers(){
    while (true) {
        errno = 0; // so we can distinguish errors from no more entries
        passwd* entry = getpwent();
        if (!entry) {
            if (errno) {
                std::cerr << "Error getting all system users\n";
                break;
            }
            break;
        }
        systemUsers[entry->pw_name] = entry->pw_dir;
    }
    endpwent();
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
    // http://www.cplusplus.com/reference/string/string/find_last_of/
    size_t found = path.find_last_of("/\\");
    string parent = path.substr(0,found);

    updatePrompt(path.substr(found+1));
    CURRENT_DIR = path;
}


void updatePrompt(string folderName){
    struct passwd *p = getpwuid(getuid());
    char prefix[128] = "";
    strcat(prefix, p->pw_name);
    string pre = prefix;
    pre = pre + ":" +folderName;
    envMap["PROMPT"] = pre;
}