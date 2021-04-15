We used the given nutshell as a starting base.

Satvik Borra contributions:

I worked on most of the implementaion of built in commands, including aliases and environmental variable handling.
I worked on the execution of non built in commands, including creating a command table structure and handling piping between commands, and the actual I/O redirection of stdin, stdout and stderr from given input, output, and output error files.
I worked on the CD command and directory expansion from the . and .. conventions to absolute paths.
I worked on executing the command table in the background and I/O redirection of build in commands alias and printenv.

Raghu Radhakrishnan contributions:
I worked on all of the input parsing, including handling built in commands, and non built in commands.
For non built in commands, I handled piping and I/O redirection input, and determining if commands exist in the PATH.
I worked on environmental variable expansion and wildcard matching.
I worked on the tilde expansion extra credit. 

What is not implemented:
Handling input from a file if the file does not end with a newline.
Handling of non characters such as arrows, and the escape key.
Auto completion with the escape key.

What is implemented:
Built in commands.
Other commands: finding them, piping them, redirecting them.
Environmental variable expansion and wildcard matching.
Tilde expansion.