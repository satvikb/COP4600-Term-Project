We used the given micro shell as a starting base.

Satvik Borra contributions:

I worked on most of the implementaion of built in commands, including aliases and environmental variable handling.
I worked on the execution of non built in commands, including creating a command table structure and handling piping between commands, and the actual I/O redirection of stdin, stdout and stderr from given input, output, and output error files.
I worked on the CD command and directory expansion from the . and .. conventions to absolute paths.
I worked on executing the command table in the background and I/O redirection of build in commands alias and printenv.
I worked on the escape auto completion

Raghu Radhakrishnan contributions:
I worked on all of the input parsing, including handling built in commands, and non built in commands.
For non built in commands, I handled piping and I/O redirection input, and determining if commands exist in the PATH.
I worked on environmental variable expansion and wildcard matching.
I worked on the tilde expansion extra credit. 

For the most part, every feature has been implemented, however the following bugs still persist in our shell:
- When a file is inputted to the nutshell program and the file does not end with a newline, the shell hangs. (i.e. ./nutshell < commands.txt)
- When a process is run in the background, subsequent prompts are printed in an unexpected order.
- Changing an environment variable that's pointed to by an existing environment variable does not update the value of that existing environment vairable.
- When the output of the nutshell is redirected to a file, some unknown characters are printed instead of the actual characters.
  In addition, some unexpected characters ([H[2J[3J) are printed at the beginning.
- When the output of the nutshell is redirected to a file, the output of some commands are intertwined.

What is implemented (Every command works as long as it is run in the shell directly and not through input/output redirection):
Built in commands.
Other commands: finding them, piping them, redirecting them and their error.
Environmental variable expansion and wildcard matching.
Tilde expansion.
Auto completion with the escape key.