#!/bin/bash

show_help() {
    echo help is on the way
}

parse_command_line_options() {
    local OPTIND opt
    echo debug: parsing
    while getopts "h?r:g:p:d:t:" opt; do
	echo "before case"
	case "$opt" in
	    h|\?)
		show_help
		exit 0
		;;
	    r)  recipe=$OPTARG
		echo building according to recipe $recipe
		;;
	    g)  gluex_install_dir=$OPTARG
		;;
	    p)  gluex_prereqs_script=$OPTARG
		;;
	    d)  container_meta_dir=$OPTARG
		;;
	    t)  dist_token=$OPTARG
		;;
	esac
    done
    shift $((OPTIND-1))

#    recipe=$1
#    gluex_install_dir=$2
    #    gluex_prereqs_script=$3
    echo "done parsing"
}

parse_command_line_options "$@"

if [ -z "$container_meta_dir" ]
then
    container_meta_dir=/tmp
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
singularity build --sandbox $raw_sandbox $recipe

if [ -d $gluex_sandbox ]
then
    echo gluex sandbox $gluex_sandbox exists, exiting
    exit 1
fi
cp -pr $raw_sandbox $gluex_sandbox
singularity exec --writable $gluex_sandbox mkdir /gluex_install
singularity exec --bind $gluex_install_dir:/gluex_install --writable $gluex_sandbox /gluex_install/$gluex_prereqs_script

if [ -d $gluex_sif ]
then
    echo gluex simg $gluex_sif exists, exiting
    exit 1
fi
singularity build $gluex_sif $gluex_sandbox


