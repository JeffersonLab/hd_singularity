#!/bin/bash

show_help() {
    cat <<EOF
Usage: create_gluex_container.sh [-h] -g FILE [-d DIRECTORY] [-t STRING] SINGULARITY_RECIPE_FILE

Note: must be run as root

Options:
  -h print this usage message
  -g script that installs gluex software
  -d output directory for containers (default: current working directory)
  -t token to be used to name containers (default = ext in "Singularity.ext")
EOF
}

parse_command_line_options() {
    local OPTIND opt
    while getopts "h?g:d:t:" opt; do
	case "$opt" in
	    h|\?)
		show_help
		exit 0
		;;
	    g)  gluex_prereqs_script=$OPTARG
		;;
	    d)  container_meta_dir=$OPTARG
		;;
	    t)  dist_token=$OPTARG
		;;
	esac
    done
    shift $((OPTIND-1))
    recipe=$1
}

file_found_action() {
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

if [ ! -f $recipe ]
then
    echo ERROR: recipe file $recipe not found
    exit 2
fi

if [ -z "$container_meta_dir" ]
then
    container_meta_dir=.
fi

if [ -z "$dist_token" ]
then
    if [ echo $dist_token | grep -l 'Singularity.' ]
       then
	   dist_token=`echo $recipe | awk -FSingularity. '{print $2}'`
    else
	dist_token=container
    fi
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
    singularity build --sandbox $raw_sandbox $recipe
fi

ls -l $gluex_prereqs_script
if [[ -z $gluex_prereqs_script || ! -f $gluex_prereqs_script ]]
then
    echo ERROR: gluex software install script $gluex_prereqs_script not found
    exit 3
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
   echo INFO: installing gluex software into $gluex_sandbox using $gluex_prereqs_script
   gpbase=`basename $gluex_prereqs_script`
   gpdir=`dirname $gluex_prereqs_script`
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

