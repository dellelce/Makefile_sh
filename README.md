## DESCRIPTION

	A small script to automate Makefile generation.
	The idea comes after "GNU Configure" but much more lightweight and easier to use.
	No support for creating platform configuration file or testing compiler features 
	just plain Makefile generation.

## TODO

* Bring up-to-date to my current (better) style
* Better handling of "#include"
* Determine if a python version would be useful

## AUTHOR
	Antonio Dell'Elce

## LICENSE

	BSD

## OPTIONS
        
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
