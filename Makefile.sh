#!/bin/bash
#
#
# Builds Makefile "automatically"
#
# (c) Antonio Dell'elce
#
# ## Change Log will be here -- until now (1743 190812) updates comments are all 
#

## ENVIRONMENT & CONFIGURATION ##

 [ -z "${DEFSHOME}" ] &&
   {
     #behaviour change; use current directory as DEFSHOME, previously it woull complain
     # changed on 2333 130713
     export DEFSHOME="$PWD"
   }

## Sanity check - Added 2331 071109

 [ ! -d "${DEFSHOME}" ] &&
   {
     echo "DEFSHOME is not a valid directory!"
     exit 1
   }

 # 1607 190812 added MYPATH
 export MYPATH="$(dirname $(readlink  -f "$0"))"

 export THISSCRIPT="$MYPATH/Makefile.sh"

 export RUNLOG="$HOME/.lmk"

 export ARGS="$*"
 export XECHO_PROG="cecho.sh"
 export MYSELF="Antonio Dell'elce"

# SunOS kludge (Standard 'awk' for SunOS is TOO OLD!)

 [ $(uname) != "SunOS" ] &&
   {
     export AWK="awk"
   } ||
   {
     export AWK="/usr/xpg4/bin/awk"
     [ ! -x "$AWK" ] && AWK="awk" # fallback to hell 2308 040910
   }

# Clear possible trash

 CHILD_RUN=0
 RUN_MAKE_REDO=0
 unset DEBUG_MAKEFILE
 unset DEBUG
 unset SUBPROJECTS
# unset LIBS
 unset INCLUDES
# unset MODULES_LIBS
# unset MODULES_LIBDIR
# unset MODULES_INCLUDES
 unset RULES
 unset DEFSDIR
 unset CFILES

# Duplicate stdout FD 

 DEBUG_FD=5 
 eval "exec $DEBUG_FD>&1"

#
# Configuration Variables (gcc only)
#

CompilerName="gcc"
[ -z "${CompilerFlags}" ] && CompilerFlags="-Wall -O2"
    
  ############# execution log #############


 # 1606 190812 test if RUNLOG actually exists before writing log entry (should use a flag?)
 [ -f "$RUNLOG" ] && echo "$(pwd),$(date), $ARGS" >> $RUNLOG

  ############# locate color echo version #############

## FUNCTIONS ##

 unset XECHO

find_xecho()
{
 typeset Item
 typeset FOUND=$(

   IFS=":"
   for Item in ${PATH}
   do
     [ -x "${Item}/${XECHO_PROG}" ] && echo "${Item}/${XECHO_PROG}"
   done | uniq
)
 echo $FOUND 
}

  XECHO=$(find_xecho)

  ############# DECHO #############

#
# Debug echo function
#

DECHO()
{
  typeset ESC=""
  [ ! -z "${DEBUG}" ] &&  eval "echo ${ESC}[1mDEBUG${ESC}[0m $(date +%H%M): \"$*\"   1>&$DEBUG_FD";
}

WECHO()
{
 typeset ESC=""
 eval "echo ${ESC}[1mWARNING${ESC}[0m $(date +%H%M): \"$*\"   1>&$DEBUG_FD";
}
  ############# process_newdefs #############

#
# Convert new .defs format to a shell script.
#

process_newdefs()
{
 typeset NewDefsFile="$1"

 DECHO "process_newdefs: $NewDefsFile"

 [ -z "${NewDefsFile}" ] &&
  {
    echo "process_newdefs: Use an argument"
    return 1
  }

 [ ! -s "${NewDefsFile}" ] &&
  {
    echo "process_newdefs: \"${NewDefsFile}\" is not a file."
    return 1
  }

#  1529 190812 moved awk code to an external file

 DECHO "process_newdefs: Running awk for: $NewDefsFile"
 $AWK -f "$MYPATH/process_newdefs.awk" "$NewDefsFile"
}


  ############# cleanup_func #############

# Enable clean handling of Control-C key 

cleanup_func()
{
  echo
  echo "**** USER INTERRUPT ****"
  [ -f "${MK_DEST}" ] && rm -f $MK_DEST
  [ -f "${PROJECT_TEMP}" ] && rm -f $PROJECT_TEMP
  exit 1
}

  trap "cleanup_func" INT


  ############# process options #############

 SavedArgs=""

 while [ ! -z "$1" ] 
  do
    [ "$1" = "-d" ] &&
      {
         echo "${THISSCRIPT} will create a debug Makefile.."
         export DEBUG_MAKEFILE=1
         SavedArgs="${SavedArgs} -d"
	 shift; continue
      } 

    [ "$1" = "-R" ] &&
      {
         export REMOVE_ALL=1
         SavedArgs="${SavedArgs} -R"
	 shift; continue
      } ||
         unset REMOVE_ALL

     [ "$1" = "-q" ] &&
       {
         export FLAG_SILENT=1 
	 shift; continue
       } ||
         unset FLAG_SILENT

     [ "$1" = "-X" ] &&
       {
         SavedArgs="${SavedArgs} -X"
         export SCRIPT_DEBUG=1 
         set -x
	 shift; continue
       }

     [ "$1" = "-B" ] &&
       { 
         shift 
         [ -z "$1" ] &&
           {
             echo "Banner option (-B) needs an argument."
             continue
           } ||
           {
             export FLAG_BANNER="1"
             export BANNER_STRING="${1}"
             banner "${BANNER_STRING}"
             shift; continue
           }
       }

     [ "$1" = "-t" ] &&
     {
       shift
       [ -z "$1" ] &&
       {
         echo "Target option (-t) needs an argument."
         continue
       } ||
       {
         ForcedTarget="$1" # not exported: we won't force target on subprojects
         shift; continue
       }
     }

     [ "$1" = "-x" ] &&
       {
         SavedArgs="${SavedArgs} -x"
         export DEBUG=1 
	 shift; continue
       }

     [ "$1" = "-K" ] &&
       {
         SavedArgs="${SavedArgs} -K"
         export FLAG_CLEANALL=1 
	 shift; continue
       }

     [ "$1" = "-defs" ] &&
       {
         shift; export DEFSDIR="${1}"
         SavedArgs="${SavedArgs} -defs ${DEFSDIR}"
	 shift; continue
       }

     [ "$1" = "-newproject" -o "$1" = "-np" ] &&
       {
         export CREATE_NEW_PROJECT=1 
	 shift; continue
       }

     [ "$1" = "-redo" ] &&
       {
         export RUN_MAKE_REDO=1 
	 shift; continue
       }

     [ "$1" = "-D" ] &&
       {
         export RUN_AS_DAEMON=1 
	 shift; continue
       }

     [ "$1" = "-help" -o "$1" = "--help" ] &&
       {
# 2138 210312 doubts on usefulness of '-B' option
         cat << EOF
${THISSCRIPT} [options]

 Where options:
 
     -t            Force target 
     -d            Create a Makefile with debug options set (-DDEBUG)
     -R            Remove all pre-existing Makefiles
     -q            Operate 'silently' (as possible)
     -X            Run $(basename ${THISSCRIPT}) in debug mode.
     -K            Do a "make clean" before re-creating makefile
     -x            Print some useful DEBUG information
     -B string     Prints a very large "string"
     -defs         Sets directory to be used as container for .defs
     -redo         Runs "make redo" at the end.
     -D            Acts in the background (daemon)
     -np
     -newproject   Create an "empty" project.defs

EOF
         exit 1
       }
#
# This should be used only internally
#

    [ "$1" = "-C" ] &&
      {
        export CHILD_RUN=1; shift; continue
      }

    [ "${1}" != "${1#-}" ] &&
      {
        echo "unknown option: $1"; echo "try: Makefile.sh -help";
        exit 1
      }

    shift
  done

  ############# Start-up banner #############

  [ "${CHILD_RUN}" -eq 0 -a -z "${FLAG_SILENT}" ] &&
    {
cat << EOF
#
# Makefile.sh starting at... $(date)
#
EOF
    }

  ############# include #############

#
# To be used in projects..
#
# 
#

include()
{
 typeset RetCode=0
 DECHO "include_file $*"

 [ ! -z "$*" ] && 
   {
     typeset Item File
     typeset Temp="/tmp/include.$$.$RANDOM"

     for File in $*
     do
       [ "${File}" = "${File%.defs}" ] &&
         {
           File="${File}.defs"
         }

       [ ! -z "${DEFSDIR}" -a -d "${DEFSDIR}" ] &&
         {
           [ -f "${DEFSDIR}/${File}" ] && File="${DEFSDIR}/${File}"
         }

       [ -d "defs" ] &&
         {
           [ -z "${DEFSDIR}" ] && DEFSDIR="$PWD/defs"
           [ -f "defs/${File}" ] && File="defs/${File}"
         }

       [ ! -f "${File}" ] &&
         {
           [ -f "${DEFSHOME}/defs/${File}" ] && File="${DEFSHOME}/defs/${File}"
         }

       [ ! -f "${File}" ] &&
         {
           [ -f "${DEFSHOME}/${File}" ] && File="${DEFSHOME}/${File}"
         }

       typeset frc=0 # shell bug(?) workaround "||" was ignored 

       [ -f "$File" ] && frc="1"

       [ "$frc" -eq 1 ] &&
         {
           process_newdefs $File > $Temp
           [ $? -eq 0 ] && . $Temp 2> /dev/null
           RetCode=$? 
           [ -z "${NO_DEFS_RM}" ] && rm -f $Temp 
           [ ! -z "${NO_DEFS_RM}" ] && DECHO "not deleted temp file: $Temp"
         }

       [ "$frc" -eq 0 ] &&
         {
           echo "include: \"$File\" is not a file. Skipped."; RetCode=1; break
         }
     done
   }

 return "${RetCode}"
}

  ############# find_includes #############

#
# Find all #include's in a C file. 
#
# WARNING: does not handle well-commented "#include"
#

find_includes()
{
 DECHO "find_includes: $1"

 typeset Item ItemDir
 typeset INFILE="$(echo $1 || xargs echo )"
 typeset ItemList=""
 
 typeset RAW_INCLUDE_FILES=$( $AWK '
$1 ~ /^#include/ { 
	  	   c=substr($2,1,1);

		   if (c == "\"") 
		    {
		      gsub (/"/,"", $2);
		      print $2;
		    }
	         }
' $INFILE
) 

 DECHO "Raw include files: ${RAW_INCLUDE_FILES}"

 for Item in ${RAW_INCLUDE_FILES}
 do
   DECHO "find_includes: header: ${Item}"
   typeset CkCnt=0

   for ItemDir in ${INCLUDES}
   do
     [ -f "${ItemDir}/${Item}" ] &&
       {
         DECHO "find_includes: path: ${ItemDir}/${Item}"
         ItemList="${ItemList} ${ItemDir}/${Item}"
         CkCnt=1
         break
       }
   done

   [ "${CkCnt}" -eq 0 ] && 
     {
       WECHO "find_includes: path not found: Source file = $INFILE Item = ${Item}: Include dirs: ${INCLUDES}"
     }
 done 

 echo $ItemList
}

  ############# mk_libs_var #############

mk_libs_var()
{
 typeset DirItem LibItem

 DECHO "mk_libs_var: MODULES_LIBDIR = ${MODULES_LIBDIR}"
 DECHO "mk_libs_var: MODULES_LIBS = ${MODULES_LIBS}"

 [ ! -z "${MODULES_LIBDIR}" ] &&
  {
    for DirItem in ${MODULES_LIBDIR}
    do
      [ -d "${DirItem}" ] &&
        {
          LIBS="${LIBS} -L${DirItem}"
        }
    done
  }

 [ ! -z "${MODULES_LIBS}" ] &&
  {
    for LibItem in ${MODULES_LIBS}
    do
      LIBS="${LIBS} -l${LibItem}"
    done
  }

}
  ############# mk_heading #############

#
# Builds a makefile "heading"


mk_heading ()
{
 DECHO "mk_heading"

 typeset THIS_YEAR=$(date +%Y)
 typeset INCL_OPTION=""
 typeset Item

cat << EOF 

#
# ${PROJECT}, ${THIS_YEAR} by ${PRJ_OWNER:-$MYSELF}, ${PRJ_EMAIL:-antonio@dellelce.com}
#

CC             = ${CC:-${CompilerName}}
TARGET         = ${TARGET}

SHELL          = ${PROJECT_SHELL:-${SHELL}}

CFILES         = ${CFILES}
OFILES         = ${OFILES}
LDFLAGS	       = ${LDFLAGS}

EOF

[ ! -z "${COMMON_DEP}" ] &&
  {
cat << EOF 
COMMON_DEP     = ${COMMON_DEP}
EOF
  }


[ "${DEBUG_MAKEFILE}" == 1 ] &&
 {
   typeset DEBUG_STR="-DDEBUG -g" 
 } ||
 {
   typeset DEBUG_STR="" 
 }

INCLUDES="${MODULES_INCLUDES} ${INCLUDES}"
# Remove spaces and tabs
_INCLUDES=$(eval "echo $INCLUDES")

[ -z "${_INCLUDES}" ] && INCLUDES="."
 
for Item in $INCLUDES
do
  [ -d "${Item}" ] && 
    {
      INCL_OPTION="${INCL_OPTION} -I${Item}"
    }
done

# prepare LIBS variable...

mk_libs_var

# create header

cat << EOF 

LOC_HFILES     = ${LOCAL_HFILES}
HFILES         = \$(LOC_HFILES)

INCLUDES       = ${INCL_OPTION}
DEBUG          = ${DEBUG_STR}
EOF

# 1020 270312
# CFLAGS from environment "patch".

[ ! -z "${CFLAGS}" ] && CompilerFlags="${CFLAGS} ${CompilerFlags}"

[ -z "${DEFINES}" ] &&
  {
cat << EOF
CFLAGS         = ${CompilerFlags} ${OPT_FLAGS} \$(INCLUDES) \$(DEBUG)
EOF
  } ||
  {
cat << EOF
CFLAGS         = ${CompilerFlags} ${OPT_FLAGS} ${DEFINES} \$(INCLUDES) \$(DEBUG)
EOF
  }

cat << EOF
LIBS           = ${LIBS}

EOF

#### End of mk_heading ####
}

  ############# mk_subrules #############

mk_subrules ()
{
 [ -z "${ALL_TARGETS}" ] && return 1
 DECHO "mk_subrules"

 typeset SingleTarget 
 echo

 for SingleTarget in $ALL_TARGETS 
  do
  typeset BASE=$(basename $SingleTarget)
  typeset DIR=${SingleTarget%$BASE}
[ -z "${XECHO}" ] &&
  {
cat << EOF
$SingleTarget:
	@make -C $DIR $BASE

EOF
  } || 
  {
cat << EOF
$SingleTarget:
	@${XECHO} "Making in ${DIR}"
	@make -C $DIR $BASE

EOF
  }

  done

}


  ############# mk_heading_rules #############


mk_heading_rules()
{
 DECHO "mk_heading_rules"
 
cat << EOF

#
# --- RULES ---
#

EOF

[ ! "${TYPE}" = "lib" ] &&
  {
cat << EOF
all: \$(TARGET)

\$(TARGET): $(get_custom_rules_targets) ${ALL_TARGETS} \$(OFILES)
	@echo "LINK " \$(TARGET)
	@\$(CC) -o \$(TARGET) \$(LDFLAGS) \$(OFILES) \$(LIBS)
EOF
  } ||
  {
cat << EOF
all: $(get_custom_rules_targets) \$(TARGET) 

\$(TARGET): \$(OFILES)
	\$(AR) rv \$(TARGET) \$(OFILES)
EOF
  }
}


  ############# get_custom_rules_targets #############

get_custom_rules_targets ()
{
 DECHO "get_custom_rules_targets"

  [ -z "$RULES" ] &&
    {
     return 1
    }

 typeset SingleRule SingleItem

 for SingleRule in $RULES
  do
   AllRules="${AllRules} $(eval echo \$RULE_TARGET_${SingleRule}) "
  done
 echo "$AllRules"
}

  ############# mk_custom_rules #############


mk_custom_rules ()
{
  DECHO "mk_custom_rules"

  [ -z "$RULES" ] &&
    {
     return 1
    }

 echo
 typeset SingleRule SingleItem

 for SingleRule in $RULES
  do
    eval echo \$RULE_TARGET_${SingleRule}: \$RULE_INPUT_${SingleRule}
    SingleItem=$(eval echo "	\$RULE_COMMANDS_${SingleRule}")
    echo "	@echo RULE ${SingleRule}"
    echo "	@${SingleItem}"
    echo
  done
}


  ############# mk_body #############


mk_body()
{
 DECHO "mk_body"

 typeset IN OBJ_PREFIX OBJ_FILE
 typeset Item

[ -d "${OBJ_DIR}" ] && 
  {
    OBJ_DIR="${OBJ_DIR}"
  } ||
  {
    # Make sure there is no trash in that variable.
    OBJ_DIR=""
  }


cat << EOF

#
# -- DEPS --
#

EOF

for Item in $CFILES
 do
   DECHO "Processing file ${Item}"
   OBJ_FILE=$(basename $Item)
   OBJ_FILE=${OBJ_DIR}${OBJ_FILE%.c}.o
   INCL_DEPS=$(find_includes $Item)

 [ ! -z "$COMMON_DEP" ] &&
   {
      echo "# ObjFile is ${OBJ_FILE}"

 cat << EOF
${OBJ_FILE}: $IN \$(HFILES) \$(COMMON_DEP) ${INCL_DEPS}
 	@echo "CC "${Item}
	@\$(CC) -c \$(CFLAGS) -o ${OBJ_FILE} ${Item}

EOF
   } ||
   {
 cat << EOF
${OBJ_FILE}: ${Item} \$(HFILES) ${INCL_DEPS}
	@echo "CC "${Item}
	@\$(CC) -c \$(CFLAGS) -o ${OBJ_FILE} ${Item}

EOF
   }


typeset _CFILES=$(
 for Item in $CFILES
  do
   echo $Item
  done
)

done
}


############# mk_clean #############

mk_clean ()
{
cat << EOF
 
#  
# clean
#    
     
clean:
	rm -f \$(TARGET) \$(OFILES) \$(LOC_HFILES) *.exe
EOF

typeset SubProject

[ ! -z "${SUBPROJECTS}" ] && 
for SubProject in $SUBPROJECTS
do
cat << EOF
	@make -C ${SubProject} clean 
EOF
done
typeset CustomTargets=$(get_custom_rules_targets)

 [ ! -z "${CustomTargets}" ] &&
   {
     cat << EOF
	rm -f ${CustomTargets}
EOF
   }

}


############# mk_tail #############


mk_tail ()
{
cat << EOF

#
# redo
#

redo: clean all

EOF
}

#
# Remove all Makefiles if Requested
#

remove_makefiles ()
{
  DECHO "remove_makefiles"

  typeset SingleProject

  [ -f ${PWD}/Makefile ] &&
    { 
      echo "Deleting... ${PWD}/Makefile"
      rm -f ${PWD}/Makefile
    }
     
  [ ! -z "${SUBPROJECTS}" ] && for SingleProject in $SUBPROJECTS
    do
      [ -f "${PWD}/${IN}/Makefile" ] &&
        { 
          echo "Deleting... ${PWD}/$IN/Makefile"
        }
   done
}

get_target ()
{ 
 typeset Target="${1}"
 typeset DIR="${Target%project.defs}"
 typeset ArgBase="${Target#${DIR}}"

 [ -z "$1" ] && 
   {
     DECHO "get_target: empty arguments"
     return 1
   }

 DECHO "get_target: target: ${Arg}"

# Let's find out "Argument" (project.defs or something like that)

 [ ! -f "${Arg}" ]
   {
     [ -f "${DIR}/defs/${ArgBase}" ] && Arg="${DIR}/defs/${ArgBase}"
   } 

 [ ! -f "${Arg}" ] && 
   {
     DECHO "get_target: not a file: ${Arg}"
     return 2
   }

 typeset Item
 typeset TargetDefs="/tmp/include.get_target.$$.${RANDOM}"

 typeset OldWD="${PWD}"
 typeset OldDEBUG="${DEBUG}"

# unset DEBUG

 cd ${DIR}
 process_newdefs "${Arg}" > ${TargetDefs} 

 [ $? -eq 0 ] &&
   {
      . $TargetDefs
      [ ! -z "$ForcedTarget" ] && TARGET="$ForcedTarget"
      echo ${DIR}${TARGET}
   } ||
   {
     return 1
   }

 [ ! -z "${OldDEBUG}" ] && DEBUG="${OldDEBUG}"
 [ -z "${NO_DEFS_RM}" -a -f "${TargetDefs}" ] && rm -f "${TargetDefs}"

 cd "${OldWD}"
 return $?
}

perform_sanity_checks()
{
#
# Minimal sanity checks
#

 [ -z "${TARGET}" ] && 
   {
     echo "Target is null, you might have an invalid project file"
     exit 1
   }
}


#
##
### 	MAIN
##
#


########### -- Environment -- ########### 

[ -z "$TMP" -o ! -d "$TMP" ] && TMP="/tmp"
MK_DEST="${TMP}/Makefile.$$.$RANDOM"
MK_SRC="Makefile"
PROJECT_FILE="$PWD/project.defs"

[ ! -f "${PROJECT_FILE}" ] && PROJECT_FILE="$PWD/defs/project.defs"

PROJECT_TEMP="${TMP}/project.defs.$$.$RANDOM"
PLATFORM_FILE="$PWD/$(uname -o 2> /dev/null).defs"
[ -z "$PROJECT" ] && PROJECT="project"
TARGET="target"

#
#
#  Load project file
#
#

DECHO "Loading Main project file"

[ -f "$PROJECT_FILE" ] &&
  {
    process_newdefs $PROJECT_FILE > ${PROJECT_TEMP}
    [ $? -eq 0 ] && . ${PROJECT_TEMP}
    rm -f ${PROJECT_TEMP}
  } ||
  {
    echo 
    echo "project.defs was not found... using internal defaults"
    echo 

    [ -d "./src" ] && SRC_DIR=./src
    [ -d "./obj" ] && OBJ_DIR=./obj

    dn="$(basename $(dirname $PWD))"

    PROJECT="$dn"
    [ -z "$ForcedTarget" ] && { TARGET="$dn"; } || { TARGET="$ForcedTarget"; } 
  }

#
# Minimal sanity checks
#

perform_sanity_checks

#
#
#  Load platform file
#
#

[ -f "$PLATFORM_FILE" ] &&
  {
    . $PLATFORM_FILE
  }

#
#
#  Load optional files
#
#
 [ ! -z "$LOAD_FILES" ] &&
   {
     for Item in $LOAD_FILES
       do
         [ -f "$Item" ] && . $Item
       done
   }

#
#
#  Check for particular Object and Source directories 
#
#

[ -d "${OBJ_DIR}" ] && 
  {
    OBJ_DIR="${OBJ_DIR}/"
  } ||
  {
    # Make sure there is no trash in that variable.
    OBJ_DIR=""
  }

[ -d "${SRC_DIR}" ] && 
  {
    SRC_DIR="${SRC_DIR}/"
  } ||
  {
    # Make sure there is no trash in that variable.
    SRC_DIR=""
  }

#
#  Builds list of .c files and related Object files (.o)
#

#OTHER_CFILES="${CFILES}"

CFILES="${SRC_DIR}*.c ${CFILES}"

OFILES=$(
 for IN in $CFILES
  do
    CFILE=$(basename $IN)
    echo ${OBJ_DIR}${CFILE%.c}.o
#    unset CFILE
  done
)
unset CFILE IN
OFILES=$(echo $OFILES)
CFILES=$(
 for IN in $CFILES
  do
    echo $IN
  done
)
unset CFILE IN

CFILES=$(echo $CFILES)
#CFILES="${CFILES} ${OTHER_CFILES}"

unset IN

#
#  Start creating makefile.... 
#

 [ ! "$FLAG_SILENT" = 1 ] &&
   {
     echo "$THISSCRIPT running in $PWD..."
   }

#
# Remove all files...
#

 DECHO "Checking if needed to remove current makefiles"

 [ "${CHILD_RUN}" -eq 0 -a "${REMOVE_ALL}" = "1" ] &&
   {
     DECHO " - Removing Makefiles..."
     remove_makefiles

     echo
   }

#
# Retrieve Sub-project name
#

 unset ALL_TARGETS

 DECHO "Verifying if we need to load subprojects"

 [ ! -z "$SUBPROJECTS" ] &&
   {
     for IN in $SUBPROJECTS
       do
         DECHO "Processing subproject: ${IN}"

         [ ! -z "${FLAG_CLEANALL}" -a -f "$PWD/$IN/Makefile" ] &&
           {
             make -C $PWD/$IN clean
           }

         [ -f "$PWD/$IN/project.defs" -o -f "${PWD}/${IN}/defs/project.defs"  ] &&
           {
             # Execute Makefile.sh in each subproject  directory
             DECHO "Found subproject dir: ${PWD}/${IN}"
             ALL_TARGETS=" ${ALL_TARGETS} $(get_target $PWD/$IN/project.defs ) "

             DECHO "All Targets: ${ALL_TARGETS}"

             (
               echo
               echo "Sub-project: $IN"
               cd $PWD/$IN
#               [ -z "${DEFSDIR}" ] && 
#                 {
#                   DECHO "Running $THISSCRIPT -C -q ${ARGS}"
#                   $THISSCRIPT -C -q ${ARGS}
#                 } ||
#                 {
#                   DECHO "Running $THISSCRIPT -C -q ${ARGS} -defs ${DEFSDIR}"
#                   $THISSCRIPT -C -q ${ARGS} -defs "${DEFSDIR}"
#                 }

               DECHO "Running $THISSCRIPT -C -q ${SavedArgs}"
               $THISSCRIPT -C -q ${SavedArgs}

               echo "Completed: $IN"
               echo
             )
           }
       done

     [ ! -z "${ALL_TARGETS}" ] && { echo "Sub Targets are ${ALL_TARGETS}"; }
   }



#
# Runs Pre-exec scripts
#
 DECHO "Verifying if we need to run any pre execution script."

 [ -f "$PRE_EXEC" ] &&
   {
     echo "Running PRE_EXEC..."
     echo
     $SHELL $PWD/$PRE_EXEC

     [ "$?" -eq "1" ] &&
       {
         echo "Pre-exec script failed!! Exiting...."
         exit 1
       }
   }

#
#
# Creates new Makefile
#
#

 DECHO "Creating Makefile"

(
# unset DEBUG
 mk_heading
 mk_heading_rules
 [ ! -z "${ALL_TARGETS}" ] && mk_subrules
 mk_custom_rules
 mk_body
 mk_clean
 mk_tail
) >> $MK_DEST

#
# Verifies Makefile differences and optionally copies it.
#
 DECHO "Verifying if new Makefile has any change."

 [ -f "$MK_SRC" ] &&
  {
    CNT=$(diff -c $MK_SRC $MK_DEST | wc -l)

    [ "$CNT" -eq "0" ] &&
     {
      echo "There are no differences in the new and old makefile!!"
     } ||
     {
      cp $MK_DEST $MK_SRC

      echo
      echo "Makefile updated:"
      [ -f "${MK_SRC}" ] && 
        {
          ls -lt ${MK_SRC}
        }
     }
  } ||
  {
    cp $MK_DEST $MK_SRC
    echo "New Makefile:"
    ls -lt $MK_SRC
  }

#
# Runs Post exec scripts
#

 DECHO "Verifying if we need to run any post execution script."

 [ -x "$POST_EXEC" ] &&
   {
     echo "Running POST_EXEC..."
     $SHELL $PWD/$POST_EXEC

     [ "$?" -eq "1" ] &&
       {
         echo "Post-exec script failed!! Exiting...."
         exit 1
       }
   }

######## -- Clean up -- ########

rm -f $MK_DEST

#
# Verify if we have been asked to run "make redo"
#

 DECHO "Verifying if we have been asked to run \"make redo\""

 [ "${CHILD_RUN}" -ne 1 -a "${RUN_MAKE_REDO}" -eq 1 ] &&
   {
      DECHO "Running make redo..."
      make redo
      RUN_MAKE_REDO="0"
   }
 
 

############# End of File #############

