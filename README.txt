DESCRIPTION

	A small script to automate Makefile creation.
	The idea comes after "GNU Configure" but much more lightweight and easier to use.
	No support for creating platform configuration file or testing compiler features 
	just plain Makefile creation.

AUTHOR
	Antonio Dell'Elce

COPYRIGHT

	TBD - Possibly BSD

OPTIONS
        
     -d            Create a Makefile with debug options set (-DDEBUG)
     -R            Remove all pre-existing Makefiles
     -q            Operate 'silently' (as possible)
     -X            Run Makefile.sh in debug mode.
     -K            Do a "make clean" before re-creating makefile
     -x            Print some useful DEBUG information
     -B string     Prints a very large "string"
     -defs         Sets directory to be used as container for .defs
     -redo         Runs "make redo" at the end.
     -D            Acts in the background (daemon)
     -np
     -newproject   Create an "empty" project.defs

