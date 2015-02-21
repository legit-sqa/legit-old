#!/bin/sh

. git-sh-setup

require_work_tree

proposal=

get_proposal()
{
    proposal=`git show-ref -s $1`

    if [ -z "$proposal" ]; then
        echo "fatal: $1 could not be resolved to a commit"
        usage
    fi

    git checkout --quiet tracking -- .tracking/proposals/$proposal
}

while test $# != 0
do
    case "$1" in
        -p|--proposal)
            shift

            proposal_branch=$1

            if [ -z "$proposal_branch" ]; then
                echo "-p|--proposal requires a proposal"
                usage
            fi

            get_proposal $proposal_branch
            ;;
        *)
            usage
    esac
    shift
done

if [ -z "$proposal" ]; then
    head=`git symbolic-ref -q HEAD`

    if [[ $head != refs/heads/proposals/* ]]; then
        echo "You have not provided a proposal, and are not currently in a proposal branch"
        usage
    fi

    get_proposal $head
fi

cat .tracking/proposals/$proposal/proposal

files=`find .tracking/proposals/$proposal/* -printf %f`

echo $files | while read $file; do
    if [[ $file != "proposal" ]] && [ -n "$file" ]; then
        cat .tracking/proposals/$proposal/$file
    fi
done