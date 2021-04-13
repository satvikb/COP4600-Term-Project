%{
#include "nutshparser.tab.h"
#include "global.h"
#include "dirent.h"
#include <string.h>
#include <unistd.h>

//#define unput(c) {yytchar= (c); if(yytchar=='\n') {yylineno--; *yysptr++=yytchar;}
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
<string_condition>[\"]          {BEGIN(INITIAL);}

<cmd_condition>{CHAR}+          {                                   
                                    //printf("yytext: %s\n", yytext);
                                    yylval.string = strdup(yytext);
                                    return STRING;                            
                                }     
<cmd_condition>"\n"		        { BEGIN(INITIAL); return END; }
<cmd_condition>"|"              { BEGIN(INITIAL); return PIPE; }

<environment_condition>{CHAR}+  {                                   
                                    //printf("yytext: %s\n", yytext);
                                    yylval.string = strdup(yytext);
                                    return STRING;                            
                                }
<environment_condition>"}"      { BEGIN(INITIAL); }

[ \t\r]		            { }
bye                 { return BYE; }
cd		            { BEGIN(cmd_condition); return CD; }
alias		        { BEGIN(cmd_condition); return ALIAS; }
unalias             { BEGIN(cmd_condition); return UNALIAS; }
setenv		        { BEGIN(cmd_condition); return SETENV; }
unsetenv            { BEGIN(cmd_condition); return UNSETENV; }
printenv            { BEGIN(cmd_condition); return PRINTENV; }
"\n"		        { return END; }
"|"                 { return PIPE; }
"${"                { BEGIN(environment_condition); }
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
