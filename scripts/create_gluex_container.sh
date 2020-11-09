#!/bin/bash

show_help() {
    cat <<EOF
Usage: create_gluex_container.sh [-h] -r <recipe-file> -p <prereqs-script> [-d DIRECTORY] [-t STRING]

Note: must be run as root

Options:
  -h print this usage message
  -r Singularity recipe file
  -p script that installs gluex software
  -d output directory for containers (default: current working directory)
  -t token to be used to name containers (default = ext in "Singularity.ext")
EOF
}

parse_command_line_options() {
    local OPTIND opt
    while getopts "h?r:p:d:t:" opt; do
	case "$opt" in
	    h|\?)
		show_help
		exit 0
		;;
	    r)  recipe=$OPTARG
		;;
	    p)  prereqs_script=$OPTARG
		;;
	    d)  container_meta_dir=$OPTARG
		;;
	    t)  dist_token=$OPTARG
		;;
	esac
    done
    shift $((OPTIND-1))
}

file_found_action() { # call this when the container already exists
    prompt_in=$1
    file_in=$2
    prompt="$prompt_in
quit/keep/overwrite? "
    while true; do
	read -p "$prompt" qco
	case $qco in
            [Qq]* ) exit 4;;
            [Kk]* ) result=keep; break;;
	    [Oo]* ) rm -rf $file_in; result=build; break;;
	    * ) echo "Please answer quit, keep, or overwrite";;
	esac
    done
}

parse_command_line_options "$@"

if [ -z $recipe ]
then
    echo ERROR: recipe file argument missing
    exit 4
fi

if [ ! -f $recipe ]
then
    echo ERROR: recipe file $recipe not found
    exit 2
fi

if [ -z $prereqs_script ]
then
    echo ERROR: prerequisite script missing \(-p option missing\)
    exit 5
fi
	  
if [ ! -f $prereqs_script ]
then
    echo ERROR: prerequisite script $prereqs_script not found
    exit 3
fi

if [ -z "$container_meta_dir" ]
then
    container_meta_dir=.
fi

if [ -z "$dist_token" ]
then
    recipe_base=`basename $recipe`
    if [[ $recipe_base =~ ^Singularity\. ]]
    then
	dist_token=`echo $recipe_base | awk -FSingularity\. '{print $2}'`
    else
	dist_token=container
    fi
fi

if [ $USER != root ]
then
    echo ERROR: must be run as root
    exit 6
fi

raw_sandbox=$container_meta_dir/$dist_token
gluex_sandbox=$container_meta_dir/gluex_$dist_token
gluex_sif=$container_meta_dir/gluex_$dist_token.sif

result=build
if [ -d $raw_sandbox ]
then
    file_found_action "raw sandbox $raw_sandbox exists" $raw_sandbox
fi
if [ $result == build ]
then
    echo INFO: building sandbox container $raw_sandbox according to $recipe
    if ! singularity build --sandbox $raw_sandbox $recipe
    then
	echo ERROR: error building $raw_sandbox
	exit 7
    fi
fi

result=build
if [ -d $gluex_sandbox ]
then
    file_found_action "gluex sandbox $gluex_sandbox exists" $gluex_sandbox
fi
if [ $result == build ]
then
   echo INFO: copying $raw_sandbox to $gluex_sandbox
   cp -pr $raw_sandbox $gluex_sandbox
   echo INFO: creating /gluex_install mount point in $gluex_sandbox
   singularity exec --writable $gluex_sandbox mkdir /gluex_install
   echo INFO: installing gluex software into $gluex_sandbox using $prereqs_script
   gpbase=`basename $prereqs_script`
   gpdir=`dirname $prereqs_script`
   singularity exec --bind $gpdir:/gluex_install --writable $gluex_sandbox /gluex_install/$gpbase
fi

result=build
if [ -f $gluex_sif ]
then
    file_found_action "gluex simg $gluex_sif exists" $gluex_sif
fi
if [ $result == build ]
then
    echo INFO: build squashfs sandbox $gluex_sif from $gluex_sandbox
    singularity build $gluex_sif $gluex_sandbox
fi

