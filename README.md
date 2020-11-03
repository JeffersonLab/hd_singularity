# hd_singularity
Files to support building and maintenance of Singularity containers for Hall D.

Contains scripts and recipes for creating Singularity containers from scratch.

The main script is scripts/create_gluex_container.sh. Its usage message is as follows:

    Usage: create_gluex_container.sh [-h] -g FILE [-d DIRECTORY] [-t STRING] SINGULARITY_RECIPE_FILE
    Note: must be run as root
    Options:
      -h print this usage message
      -g script that installs gluex software
      -d output directory for containers (default: current working directory)
      -t token to be used to name containers (default = ext in "Singularity.ext")
