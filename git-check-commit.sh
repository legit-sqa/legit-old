#!/bin/sh

run_git()
{
    exit `git do-commit ${commit_args[*]}`
}

usage()
{
    git do-commit -h
    echo "Legit Extension Options:"
    printf "    --no-check"
    printf "            "
    echo "Don't check if a commit is acceptable"
    exit 0
}

cleanup()
{
    rm -r .tracking
}

# Get the commit message
no_check=false
commit_args=()
while test $# != 0
do
    case "$1" in
        --no-check)
            no_check=true ;;
        -h|--help)
            usage ;;
        *)
            commit_args+=("$1") ;;
    esac
    shift
done

. git-sh-setup

if test $no_check = true; then
    run_git
fi

require_work_tree

head=`git symbolic-ref -q --short HEAD`

if [ "$head" = "tracking" ]; then
    die "fatal: You cannot commit to the tracking branch"
fi

cd_to_toplevel
# Get the latest config file out of the database
git checkout tracking -- .tracking/config

# Normal people can't commit straight to locked branches
locked=`git config --file .tracking/config branch.$head.locked`
if [ "$locked" = "true" ]; then
    echo "fatal: You are attempting to commit to a locked branch."
    echo "Did you mean to start a new proposal?"
    echo ""
    echo "You can use git commit --no-check to bypass this check"
    cleanup
    die
fi

# Passed all guards, so we allow it to run
run_git
cleanup