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

check_for_file_existence() { # call this when the container already exists
    prompt_in=$1
    file_in=$2
    prompt="$prompt_in
quit/keep/overwrite? "
    result=build # default output
    if [ -e $file_in ]
    then
	while true; do
	    read -p "$prompt" qco
	    case $qco in
		[Qq]* ) exit 0;;
		[Kk]* ) result=keep; break;;
		[Oo]* ) rm -rf $file_in; result=build; break;;
		* ) echo "Please answer quit, keep, or overwrite";;
	    esac
	done
    fi
}

parse_command_line_options "$@"

if [ -z $recipe ]
then
    echo ERROR: recipe file argument missing
    exit 9
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

gpbase=`basename $prereqs_script`
gpdir=`dirname $prereqs_script`
if [ $gpdir == "." ] # if no directory in prereq script
then # get latest version of gluex_install and find the script there
    gin_version=`curl --silent "https://api.github.com/repos/jeffersonlab/gluex_install/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'`
    gluex_install_version_tag=_gin$gin_version
    tempdir=/tmp/$RANDOM
    mkdir -p $tempdir
    pushd $tempdir > /dev/null
    wget --no-verbose --no-check-certificate -O $gin_version.tar.gz https://github.com/JeffersonLab/gluex_install/archive/$gin_version.tar.gz
    tar zxf $gin_version.tar.gz
    gpdir=$tempdir/gluex_install-$gin_version
    popd > /dev/null
else
    gluex_install_version_tag=""
fi
	  
if [ ! -f $gpdir/$gpbase ]
then
    echo ERROR: prerequisite script $gpdir/$gpbase not found
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
	recipe_tag=`echo $recipe_base | awk -FSingularity\. '{print $2}'`
	singularity_version_tag=`singularity --version | awk '{print $3}' | awk -F- '{print $1}' | awk -F. '{print "_sng"$1"."$2}'`
	dist_token=${recipe_tag}${singularity_version_tag}${gluex_install_version_tag}
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

check_for_file_existence "raw sandbox $raw_sandbox exists" $raw_sandbox
if [ $result == build ]
then
    echo INFO: building sandbox container $raw_sandbox according to $recipe
    if ! singularity build --sandbox $raw_sandbox $recipe
    then
	echo ERROR: error building $raw_sandbox
	exit 7
    fi
elif [ $result == keep ]
then
    echo INFO: keeping $raw_sandbox
else
    echo ERROR: this cannot happen
    exit 10
fi

check_for_file_existence "gluex sandbox $gluex_sandbox exists" $gluex_sandbox
if [ $result == build ]
then
   echo INFO: copying $raw_sandbox to $gluex_sandbox
   cp -pr $raw_sandbox $gluex_sandbox
   echo INFO: creating /gluex_install mount point in $gluex_sandbox
   singularity exec --writable $gluex_sandbox mkdir /gluex_install
   echo INFO: installing gluex software into $gluex_sandbox using $prereqs_script
   if ! singularity exec --bind $gpdir:/gluex_install --writable $gluex_sandbox /gluex_install/$gpbase
   then
       echo ERROR: error installing software into $gluex_sandbox
       exit 1
   fi
elif [ $result == keep ]
then
    echo INFO: keeping $gluex_sandbox
else
    echo ERROR: this cannot happen
    exit 4
fi

check_for_file_existence "gluex simg $gluex_sif exists" $gluex_sif
if [ $result == build ]
then
    echo INFO: build squashfs sandbox $gluex_sif from $gluex_sandbox
    if ! singularity build $gluex_sif $gluex_sandbox
    then
	echo ERROR: error creating squashfs container $gluex_sif
	exit 8
    fi
elif [ $result == keep ]
then
    echo INFO: keeping $gluex_sif
else
    echo ERROR: this cannot happen
    exit 11
fi

echo INFO: done
exit 0
