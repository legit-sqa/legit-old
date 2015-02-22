#!/bin/sh

USAGE='[-m <message>]'
. git-sh-setup

# Why on earth do I have to write my own contains function!?
contains() {
    search=$1
    shift
    array=$*
    if [[ ${array[@]} == *$search* ]]
    then
        for element in "${array[@]}"
        do
            if [[ $element == $search ]]
            then
                return 0
            fi
        done
    fi

    return 1
}

# Get the commit message
message=
is_fix=false
while test $# != 0
do
    case "$1" in
        -m)
            shift

            # Get the message, but trim whitespace from it
            message=`echo $1 | sed 's/^\s*//;s/\s*$//'`

            # This will be blank if the user either failed to provide a
            # message, or if it was only whitespace (which we reject)
            if [ -z "$message" ]; then
                usage
            fi
            shift
            ;;
        -f|--is-fix)
            is_fix=true ;;
        *)
            usage
    esac
    shift
done

# People need to specify a message!
if [ ! -n "$message" ]; then
    echo "# Please enter the proposal message for your changes. Lines starting" > .git/PROPOSAL_EDITMSG
    echo "# with '#' will be ignored, and an empty message aborts the proposal." >> .git/PROPOSAL_EDITMSG

    git_editor .git/PROPOSAL_EDITMSG

    # Remove comments, whitespace and blank lines
    message=`sed '/\s*#/d;s/^\s*//;s/\s*$//;/./,$!d' .git/PROPOSAL_EDITMSG`

    if [ -z "$message" ]; then
        echo "Aborting because of empty message"
        exit 0
    fi
fi

# Has this repo been legitimised?
if ! git show-ref --quiet refs/heads/tracking; then
    >&2 echo "fatal: no tracking branch exists"
    exit -1
fi

require_clean_work_tree 'make a proposal'

# Check we're not in a locked branch, or the tracking branch
orig_head=`git symbolic-ref -q --short HEAD`
if [ "$orig_head" = "tracking" ]; then
    >&2 echo "fatal: you are in the tracking branch. Please checkout the
the branch you wish to propose."
    exit -4
fi

# The commit at the head of the proposal is used as it's ID
name=`git rev-parse --verify HEAD`

# Let's do this
git checkout --quiet tracking

# Hash collisions shouldn't happen...
if [ -d .tracking/proposals/$name ]; then
    >&2 echo "fatal: this proposal already exists"
    exit -3
fi

first=true
found=
based_on=
parent_commit=
explored=()

# Find what this is based on
for commit in $(git rev-list $name)
do
    for branch in $(git branch --contains $commit | sed 's/\*//;s/ *//')
    do
        if test true = $first; then
            explored+=("$branch")
            continue
        fi

        # Check if we've already inspected this branch. If we have it
        # obviously didn't yield anything, so we can skip it here
        if contains $branch $explored; then
            continue
        fi

        # Mark the branch as explored so we don't have to mess about
        # with it again
        explored+=("$branch")

        # Check if this commit is in a locked branch
        # If it is, we must be working of this
        locked=`git config --file .tracking/config branch.$branch.locked`
        if [ "$locked" = "true" ]; then
            found=true
            parent_commit=$commit
            break 2
        fi

        # Check if this commit is in a proposal
        branch_head=`git rev-parse --verify $branch`
        if [ -d .tracking/proposals/$branch_head ]; then
            found=true
            based_on=$branch_head
            parent_commit=$commit
            break 2
        fi
    done

    if test true = $first; then
        first=false
    fi
done

if [ $found = false ]; then
    git checkout --quiet $orig_head
    die "Couldn't find a parent proposal or locked branch for HEAD"
fi

if test true = "$is_fix" && [ -z "$based_on" ]; then
    git checkout --quiet $orig_head
    die "You've specified this is a fix, but the proposal isn't based on a proposal"
fi

# Make the proposal and fill it with the proposal message
mkdir .tracking/proposals/$name
cd .tracking/proposals/$name

echo "Proposer: $(git config user.name) <$(git config user.email)>" > proposal
echo "Submitted-at: $(date -R)" >> proposal
echo "Status: Open" >> proposal
echo "Votes: 0" >> proposal
echo "Start: $parent_commit" >> proposal

if [ -n "$based_on" ]; then
    if test true = "$is_fix"; then
        echo "Fix-of: $based_on" >> proposal
    else
        echo "Extension-of: $based_on" >> proposal
    fi
fi

echo "" >> proposal
echo "$message" >> proposal

cd ..
echo $name >> open

# Git won't shutup when adding files, so pipe everything to /dev/null
git add open >> /dev/null 2>&1
git add $name >> /dev/null 2>&1

git-commit --quiet -m "Proposed: $name"

# Need to be back in the tree root so git can delete .tracking when we
# switch back to the proposal branch
cd ../..

git checkout --quiet $orig_head
git checkout --quiet -b proposals/$name

echo "Created Proposal: $name"