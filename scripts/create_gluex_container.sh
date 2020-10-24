#!/bin/bash

show_help() {
    echo help is on the way
}

parse_command_line_options() {
    local OPTIND opt
    echo debug: parsing
    while getopts "h?g:d:t:" opt; do
	echo "before case"
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
    echo "done parsing"
}

parse_command_line_options "$@"

if [ -z "$container_meta_dir" ]
then
    container_meta_dir=.
fi

dist_token=`echo $recipe | awk -FSingularity. '{print $2}'`

raw_sandbox=$container_meta_dir/$dist_token
gluex_sandbox=$container_meta_dir/gluex_$dist_token
gluex_sif=$container_meta_dir/gluex_$dist_token.sif

if [ -d $raw_sandbox ]
then
    echo raw sandbox $raw_sandbox exists, exiting
    exit 1
fi
echo building sandbox container $raw_sandbox according to $recipe
singularity build --sandbox $raw_sandbox $recipe

if [ -d $gluex_sandbox ]
then
    echo gluex sandbox $gluex_sandbox exists, exiting
    exit 1
fi
echo copying $raw_sandbox to $gluex_sandbox
cp -pr $raw_sandbox $gluex_sandbox
echo create /gluex_install mount point in $gluex_sandbox
singularity exec --writable $gluex_sandbox mkdir /gluex_install
echo install gluex software into $gluex_sandbox using $gluex_prereqs_script
gpbase=`basename $gluex_prereqs_script`
gpdir=`dirname $gluex_prereqs_script`
singularity exec --bind $gpdir:/gluex_install --writable $gluex_sandbox /gluex_install/$gpbase

if [ -d $gluex_sif ]
then
    echo gluex simg $gluex_sif exists, exiting
    exit 1
fi
echo build squashfs sandbox $gluex_sif from $gluex_sandbox
singularity build $gluex_sif $gluex_sandbox


