#!/bin/sh

. git-legit-setup

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

do_diff=true
do_reviews=true
do_proposal=true
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
        --no-diff)
            do_diff=false ;;
        --no-reviews)
            do_reviews=false ;;
        --no-proposal)
            do_proposal=false ;;
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

if test true = "$do_proposal"
then
    cat .tracking/proposals/$proposal/proposal
    echo ""
fi

if test true = "$do_diff"
then
    start=$(read_header start .tracking/proposals/$proposal/proposal)
    git diff $start..$proposal
    echo ""
fi

if test true = "$do_reviews"
then
    for file in $(find .tracking/proposals/$proposal/* -printf %f\\n)
    do
        if [[ $file != "proposal" ]] && [ -n "$file" ]; then
            cat .tracking/proposals/$proposal/$file
        fi
    done
fi

git rm --quiet -f -r .tracking/