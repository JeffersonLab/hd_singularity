# hd_singularity
Files to support building and maintenance of Singularity containers for Hall D.

Contains scripts and recipes for creating Singularity containers from scratch.

The main script is scripts/create_gluex_container.sh. Its usage message is as follows:

    Usage: create_gluex_container.sh [-h] -r <recipe-file> -p <prereqs-script> \
           [-d DIRECTORY] [-t STRING]

    Note: must be run as root

    Options:
      -h print this usage message
      -r Singularity recipe file
      -p script that installs gluex software
      -d output directory for containers (default: current working directory)
      -t token to be used to name containers (default = extension in "Singularity.ext")
