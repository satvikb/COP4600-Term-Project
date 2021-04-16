%{
#include "nutshparser.tab.h"
#include "global.h"
#include <string.h>
#include <unistd.h>
#include <stdio.h>

//#define unput(c) {yytchar= (c); if(yytchar=='\n') {yylineno--; *yysptr++=yytchar;}

int enterCmd = 0;
int enterString = 0;

string stringBuffer = "";

char* subAliases(char* name){
    auto sub = aliasMap.find(name);
    if(sub != aliasMap.end()){
        return &sub->second[0];
    }
    return name;
}
bool ifAlias(char* name){
    return aliasMap.count(name) > 0;
}
bool ifCmd(char* arg){
    if(arg[0] == '/') {
        if( access( arg, X_OK ) == 0){
            return true;
        } else {
            return false;
        }
    } else {
        char* path = strdup( &envMap["PATH"][0]);

        char* token;

        token = strtok(path, ":");
        while(token != NULL) {            
            DIR* d;
            struct dirent *dir;

            if(strcmp(token, ".") == 0){
                // test cur dir
                // get absolute path of argument
                string fullArgPath = expandDirectory(arg);
                bool isInLocalDir = ifCmd(&fullArgPath[0]);
                if(isInLocalDir){
                    return true;
                }else{
                    // go next
                    token = strtok(NULL, ":");
                    continue;
                }
            }

            d = opendir(token);
            while((dir = readdir(d)) != NULL) {
                if(strcmp(arg, dir->d_name) == 0) {
                    char* absPath = strdup(token);
                    strcat(absPath, "/");
                    strcat(absPath, arg);

                    if( access( absPath, X_OK ) == 0 && (dir->d_type == DT_REG) ){
                        strcpy(arg, absPath);
                        return true;
                    }
                }
            }
            closedir(d);

            token = strtok(NULL, ":");
        }
    }

    return false;
}
%}
%array
%option noyywrap

CHAR            [.A-Za-z0-9!\/_:'-][.A-Za-z0-9!\/_:'-]*
CHAR_NO_SLASH   [.A-Za-z0-9!\_-][.A-Za-z0-9!\_-]*
CMD_CHAR        [*?.A-Za-z0-9!\/_':-][*?.A-Za-z0-9!\/_':-]*
ANYCHAR         [:)(*&%#@!`;,\.a-zA-Z0-9'/*_=~ -][:}{)(*&%#@!`;,\.a-zA-Z0-9'/*_=~ -]*

%x string_condition
%x cmd_condition
%x environment_condition
%%


<<EOF>>             { return EOFEND; }

<INITIAL,cmd_condition>[~]?{CHAR}+"\x1b"            { 
                                                            // cout << "ESC ON: " << yytext << endl;
                                                        yytext[strlen(yytext)-1]='\0'; // remove escape key from input
                                                        fflush(stdout);
                                                        // cout << "COMPLETE ON: " << yytext << endl;
                                                        string completed = completeString(yytext);
                                                        completed = '\"' + completed + '\"';
                                                        // cout << yytext << "ESC COMP " << completed << endl;
                                                        char *yycopy = strdup( &completed[0] );
                                                        for ( int i = strlen(&completed[0]) - 1; i >= 0; --i )
                                                            unput( yycopy[i] );
                                                        free( yycopy );
                                                    } 
<string_condition>{ANYCHAR}+     { 
    //yylval.string = strdup(yytext); return STRING;
        string str(yytext);
        stringBuffer = stringBuffer + str;
    }


<string_condition>[\"]|[”]      {
                                    enterString = 0;
                                    if(enterCmd == 0)
                                        BEGIN(INITIAL);
                                    else 
                                        BEGIN(cmd_condition);
                                    char* val;
                                    val = strdup(stringBuffer.c_str());
                                    yylval.string = val;
                                    stringBuffer = "";
                                    return STRING;
                                }

<cmd_condition>{CMD_CHAR}+      {                                   
                                    if(strchr(yytext, '*') != NULL || strchr(yytext, '?') != NULL) {
                                        vector<string> matchedFiles;

                                        DIR* d;
                                        struct dirent *dir;
                                        d = opendir(envMap["PWD"].c_str());
                                        while((dir = readdir(d)) != NULL) {
                                            if(fnmatch(yytext, dir->d_name, 0) == 0) {
                                                string s(dir->d_name);

                                                matchedFiles.push_back(dir->d_name);
                                            }
                                        }
                                        closedir(d);

                                        if(matchedFiles.size() > 0) {
                                            for(int i = 0; i < matchedFiles.size(); i++) {
                                                for(int j = matchedFiles[i].length() - 1; j >= 0; j--) {
                                                    unput(matchedFiles[i][j]);
                                                }
                                                unput(' ');
                                            }
                                        } else {
                                            for(int i = strlen(yytext) - 1; i >= 0; i--) {
                                                if(yytext[i] != '*' && yytext[i] != '?') {
                                                    unput(yytext[i]);
                                                }
                                            }
                                        }

                                    } else {
                                        yylval.string = strdup(yytext);
                                        return STRING;
                                    }
                                                                
                                }
<cmd_condition>"<"              { return IN; }
<cmd_condition>">>"             { return A_OUT; }
<cmd_condition>"2>"             { return ERROR_FILE; }
<cmd_condition>"2>&1"           { return ERROR_OUTPUT; }
<cmd_condition>"&"              { return BACKGROUND; }
<cmd_condition>">"              { return OUT; }
<cmd_condition>"\n"		        { enterCmd = 0; BEGIN(INITIAL); return END; }
<cmd_condition>"|"              { enterCmd = 0; BEGIN(INITIAL); return PIPE; }
<cmd_condition>" "              { }
<cmd_condition>"\x1b"           { }

<INITIAL,cmd_condition>[~]{CHAR_NO_SLASH}*   { 
    if(strlen(yytext) == 1) {
        string home = getenv("HOME");

        for(int i = home.length() - 1; i >= 0; i--) {
            unput(home[i]);
        }
    } else {
        char * val = strdup(yytext);
        val++;

        struct passwd* pw;

        if((pw = getpwnam(val)) == NULL) {
            // handle bad username
            cout << "User not found. Defaulting to current user" << endl;
            string home = envMap["HOME"];

            for(int i = home.length() - 1; i >= 0; i--) {
                unput(home[i]);
            }
        } else{
            for(int i = strlen(pw->pw_dir) - 1; i >= 0; i--) {
                unput(pw->pw_dir[i]);
            }
        }
    }
 }

<environment_condition>{CHAR}+[}]   {                                   

    //printf("yytext: %s\n", yytext);
    char * cpy = strdup(yytext);
    cpy[strlen(cpy) - 1] = '\0';
    //printf("yytext: %s\n", cpy);
    auto sub = envMap.find(cpy);
    //cout << sub->second << endl;

    if(sub != envMap.end()){
        for ( int i = sub->second.length() - 1; i >= 0; --i ) {
            unput( sub->second[i] );
        }
    }

    free(cpy);
    if(enterString == 1) {
        BEGIN(string_condition);
    } else if(enterCmd == 0) {
        BEGIN(INITIAL);
    } else {
        cout << "LOL" <<endl;
        BEGIN(cmd_condition);
    }                
}
<environment_condition>{CHAR}*      {
    if(enterString == 1) {
        BEGIN(string_condition);
    } else if(enterCmd == 1) {
        BEGIN(cmd_condition);
    } else {
        BEGIN(INITIAL);
    }
}
              
[ \t]		            { }
bye                 { return BYE; }
cd		            { enterCmd = 1; BEGIN(cmd_condition); return CD; }
alias		        { enterCmd = 1; BEGIN(cmd_condition); yylval.string = strdup(yytext); return ALIAS; }
unalias             { enterCmd = 1; BEGIN(cmd_condition); return UNALIAS; }
setenv		        { enterCmd = 1; BEGIN(cmd_condition); return SETENV; }
unsetenv            { enterCmd = 1; BEGIN(cmd_condition); return UNSETENV; }
printenv            { enterCmd = 1; BEGIN(cmd_condition); yylval.string = strdup(yytext); return PRINTENV; }
"\n"		        { return END; }
"|"                 { return PIPE; }

<INITIAL,cmd_condition,string_condition>"${" { BEGIN(environment_condition); }
<INITIAL,cmd_condition>[\"]|[“]  { enterString = 1; BEGIN(string_condition); }

{CHAR}+             {
                        if(ifAlias(yytext)) {
                            // printf("yytext before sub: %s\n", yytext);
                            // source: https://www.cs.princeton.edu/~appel/modern/c/software/flex/flex.html
                            char *yycopy = strdup( subAliases(yytext) );
                            for ( int i = strlen(subAliases(yytext)) - 1; i >= 0; --i )
                                unput( yycopy[i] );
                            free( yycopy );
                        } else if(ifCmd(yytext)) {
                            //printf("yytext: %s\n", yytext);
                            enterCmd = 1; 
                            BEGIN(cmd_condition);
                            yylval.string = strdup(yytext);
                            return CUSTOM_CMD; 
                        } else {
                            yylval.string = strdup(yytext);
                            return STRING;
                        };
                    }

%%
