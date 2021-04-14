%{
#include "nutshparser.tab.h"
#include "global.h"
#include "dirent.h"
#include <string.h>
#include <unistd.h>
#include <stdio.h>

//#define unput(c) {yytchar= (c); if(yytchar=='\n') {yylineno--; *yysptr++=yytchar;}

int enterCmd = 0;
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
            // command cmd;
            // cmd.commandName = arg;
            
            // commandTable.push_back(cmd);

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

CHAR            [.A-Za-z0-9!\/_-][.A-Za-z0-9!\/_-]*
ANYCHAR            [)(*&%$#@!`;,\.a-zA-Z0-9'/*_=~ -][)(*&%$#@!`;,\.a-zA-Z0-9'/*_=~ -]*

%x string_condition
%x cmd_condition
%x environment_condition
%%

<string_condition>{ANYCHAR}+     { yylval.string = strdup(yytext); return STRING;}
<string_condition>[\"]          {
                                    if(enterCmd == 0)
                                        BEGIN(INITIAL);
                                    else 
                                        BEGIN(cmd_condition);
                                }

<cmd_condition>{CHAR}+          {                                   
                                    //printf("yytext: %s\n", yytext);
                                    yylval.string = strdup(yytext);
                                    return STRING;                            
                                }
<cmd_condition>"<"              { return IN; }
<cmd_condition>">>"             { return A_OUT; }
<cmd_condition>"2>"             { return ERROR_FILE; }
<cmd_condition>"2>&1"           { return ERROR_OUTPUT; }
<cmd_condition>"&"              { return BACKGROUND; }
<cmd_condition>">"              { return OUT; }
<cmd_condition>"\n"		        { enterCmd = 0; BEGIN(INITIAL); return END; }
<cmd_condition>"|"              { enterCmd = 0; BEGIN(INITIAL); return PIPE; }
<cmd_condition>[\"]             { BEGIN(string_condition); }

<cmd_condition,environment_condition>{CHAR}+[}]    {                                   
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
                                                        if(enterCmd == 0) {
                                                            BEGIN(INITIAL);
                                                        } else {
                                                            BEGIN(cmd_condition);
                                                        }                
                                                    }

[ \t\r]		            { }
bye                 { return BYE; }
cd		            { enterCmd = 1; BEGIN(cmd_condition); return CD; }
alias		        { enterCmd = 1; BEGIN(cmd_condition); yylval.string = strdup(yytext); return ALIAS; }
unalias             { enterCmd = 1; BEGIN(cmd_condition); return UNALIAS; }
setenv		        { enterCmd = 1; BEGIN(cmd_condition); return SETENV; }
unsetenv            { enterCmd = 1; BEGIN(cmd_condition); return UNSETENV; }
printenv            { enterCmd = 1; BEGIN(cmd_condition); yylval.string = strdup(yytext); return PRINTENV; }
"\n"		        { return END; }
"|"                 { return PIPE; }
<INITIAL,cmd_condition>"${" { BEGIN(environment_condition); }
[\"]                { BEGIN(string_condition); }
{CHAR}+             {
                        if(ifAlias(yytext)) {
                            printf("yytext before sub: %s\n", yytext);
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
                            //printf("yytext: %s\n", yytext);
                            yylval.string = strdup(yytext);
                            return STRING;
                        };
                    }

%%
