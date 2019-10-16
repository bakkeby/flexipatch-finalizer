#!/bin/bash

KEEP_FILES=0
ECHO_COMMANDS=0
RUN_SCRIPT=0
DIRECTORY=.
DEBUG=0

if [[ $# = 0 ]]; then
    set -- '-h'
fi

while (( $# )); do
	case "$1" in
		-d|--directory)
			shift
			DIRECTORY=$1
			shift
			;;
		--debug)
			shift
			DEBUG=1
			;;
		-r|--run)
			shift
			RUN_SCRIPT=1
			;;
		-e|--echo)
			shift
			ECHO_COMMANDS=1
			;;
		-k|--keep)
			shift
			KEEP_FILES=1
			;;
		-h|--help)
			shift
			fmt="  %-31s%s\n"

			printf "%s" "Usage: $(basename ${BASH_SOURCE[0]}) [OPTION?]"
			printf "\n"
			printf "\nThis is a custom pre-processor designed to remove unused flexipatch patches and create a final build."
			printf "\n\n"
			printf "$fmt" "-r, --run" "include this flag to confirm that you really do want to run this script"
			printf "\n"
			printf "$fmt" "-d, --directory <dir>" "the flexipatch directory to process (defaults to current directory)"
			printf "$fmt" "-h, --help" "display this help section"
			printf "$fmt" "-k, --keep" "keep temporary files and do not replace the original ones"
			printf "$fmt" "-e, --echo" "echo commands that will be run rather than running them"
			printf "$fmt" "    --debug" "prints additional debug information to stderr"
			printf "\nWarning! This script alters and removes files within the source directory."
			printf "\nWarning! This process is irreversible! Use with care. Do make a backup before running this."
			printf "\n\n"
			exit
			;;
		*)
			echo "Ignoring unknown argument ($1)"
			shift
			;;
	esac
done

if [[ $RUN_SCRIPT = 0 ]]; then
	echo "Re-run this command with the --run option to confirm that you really want to run this script."
	echo "The changes this script makes are irreversible."
	exit 1
fi

if [[ ! -e ${DIRECTORY}/patches.h ]]; then
	printf "No patches.h file found. Make sure you run this script within a flexipatch source directory."
	exit 1
fi


FILES_TO_DELETE=$(find $DIRECTORY -name "*.c" -o -name "*.h" | awk -v DEBUG="$DEBUG" -v DIRECTORY="$DIRECTORY" '
function istrue(f) {
	ret = 0
	for ( i = 2; i <= length(f); i++ ) {
		if ( f[i] == "||" ) {
			if ( ret == -1 ) {
				ret = 0
			} else if ( ret == 1 ) {
				break
			}
			continue
		} else if ( f[i] == "&&" ) {
			if ( ret == 0 ) {
				ret = -1
			}
			continue
		} else if ( ret == -1 ) {
			continue
		} else if ( f[i] !~ /_(PATCH|LAYOUT)$/ ) {
			ret = 1
		} else if ( f[i] ~ /^!/ ) {
			ret = !patches[substr(f[i],2)]
		} else {
			ret = patches[f[i]]
		}
	}

	if ( ret == -1 ) {
		ret = 0
	}

	return ret
}

function schedule_delete(file) {
	/* Skip duplicates */
	for ( i = 1; i < length(files_to_delete); i++ ) {
		if ( files_to_delete[i] == file) {
			return
		}
	}
	if (DEBUG) {
		print "Scheduling file " file " for deletion." > "/dev/stderr"
	}
	files_to_delete[length(files_to_delete)] = file
}

function is_flexipatch(patch) {
	return patch ~ /_(PATCH|LAYOUT)$/
}

BEGIN {
	/* Read patches.h and store patch settings in the patches associative array */
	if (DEBUG) {
		print "Reading file " DIRECTORY "/patches.h" > "/dev/stderr"
	}
	while (( getline line < (DIRECTORY"/patches.h") ) > 0 ) {
		split(line,f)
		if ( f[1] ~ /^#define$/ ) {
			patches[f[2]] = f[3]
			if (DEBUG) {
				print "Found " f[2] " = " f[3] > "/dev/stderr"
			}
		}
	}
	files_to_delete[0] = ""
}

{
	level = 0
	do_print[level] = 1
	has_printed[level] = 0
	condition[level] = ""

	while (( getline line < $0) > 0 ) {
		split(line,f)
		if ( f[1] ~ /^#if$/ ) {
			do_print[++level] = do_print[level]
			has_printed[level] = 0
			condition[level] = f[2]
			if ( do_print[level] ) {
				if ( istrue(f) ) {
					has_printed[level] = 1
					do_print[level] = 1
				} else {
					do_print[level] = 0
				}
			}
			if ( is_flexipatch(condition[level]) ) {
				continue
			}
		} else if ( f[1] ~ /^#ifdef$/ || f[1] ~ /^#ifndef$/ ) {
			do_print[++level] = do_print[level]
			has_printed[level] = 0
			condition[level] = f[2]
			if ( do_print[level] ) {
				has_printed[level] = 1
				do_print[level] = 1
			}
			if ( is_flexipatch(condition[level]) ) {
				continue
			}
		} else if ( f[1] ~ /^#elif$/ ) {
			if ( has_printed[level] == 0 && do_print[level-1] == 1 ) {
				if ( istrue(f) ) {
					has_printed[level] = 1
					do_print[level] = 1
				} else {
					do_print[level] = 0
				}
			} else {
				do_print[level] = 0
			}
			if ( is_flexipatch(f[2]) ) {
				continue
			}
		} else if ( f[1] ~ /^#else$/ ) {
			if ( has_printed[level] == 0 && do_print[level-1] == 1 ) {
				has_printed[level] = 1
				do_print[level] = 1
			} else {
				do_print[level] = 0
			}
			if ( is_flexipatch(condition[level]) ) {
				continue
			}
		} else if ( f[1] ~ /^#include$/ && f[2] ~ /^"/ && (do_print[level] == 0 || f[2] == "\"patches.h\"") ) {
			dir = ""
			if ( $0 ~ /\// ) {
				dir = $0
				sub("/[^/]+$", "/", dir)
			}
			schedule_delete(dir substr(f[2], 2, length(f[2]) - 2))
			continue
		} else if ( f[1] ~ /^#endif$/ ) {
			if ( is_flexipatch(condition[level]) ) {
				level--
				continue
			}
			level--
		}

		if ( do_print[level] ) {
			print line > $0 ".~"
		}
	}
}

END {
	for ( i = 1; i < length(files_to_delete); i++ ) {
		print files_to_delete[i]
	}
}
')

# Chmod and replace files
for FILE in $(find $DIRECTORY -name "*.~"); do
	chmod --reference=${FILE%%.~} ${FILE}
	if [[ $KEEP_FILES = 0 ]] || [[ $ECHO_COMMANDS = 1 ]]; then
		if [[ $ECHO_COMMANDS = 1 ]]; then
			echo "mv ${FILE} ${FILE%%.~}"
		else
			mv ${FILE} ${FILE%%.~}
		fi
	fi
done

# Delete unnecessary files
if [[ $KEEP_FILES = 0 ]] || [[ $ECHO_COMMANDS = 1 ]]; then
	for FILE in $FILES_TO_DELETE; do
		if [[ $ECHO_COMMANDS = 1 ]]; then
			echo "rm $FILE"
		else
			rm "$FILE"
		fi
	done

	if [[ -f $DIRECTORY/README.md ]]; then
		if [[ $ECHO_COMMANDS = 1 ]]; then
			echo "rm $DIRECTORY/README.md"
		else
			rm $DIRECTORY/README.md
		fi
	fi

	# Remove empty include files
	INCLUDE_RE='*patch/*include.[hc]'
	if [[ $ECHO_COMMANDS = 1 ]]; then
		INCLUDE_RE='*patch/*include.[hc][.]~'
	fi
	for FILE in $(find $DIRECTORY -path $INCLUDE_RE); do
		if [[ $(grep -c "#include " $FILE) = 0 ]]; then
			if [[ $ECHO_COMMANDS = 1 ]]; then
				echo "rm ${FILE%%.~}"
			else
				rm "$FILE"
			fi

			for LINE in $(grep -Ern "#include \"patch/$(basename ${FILE%%.~})\"" $DIRECTORY | grep -v '.~:' | awk -F":" '{print $1 ":" $2 }'); do
				INCFILE=$(echo $LINE | cut -d":" -f1)
				LINE_NO=$(echo $LINE | cut -d":" -f2)
				if [[ $ECHO_COMMANDS = 1 ]]; then
					echo "sed -i \"${LINE_NO}d\" ${INCFILE}"
				else
					sed -i "${LINE_NO}d" ${INCFILE}
				fi
			done
		fi

	done
fi