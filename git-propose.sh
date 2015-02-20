#!/bin/sh

USAGE='[-m <message>]'
. git-sh-setup

# Get the commit message
message=
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

    printf '#'
    printf "$message"
    printf '#'

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

# Make the proposal and fill it with the proposal message
mkdir .tracking/proposals/$name
cd .tracking/proposals/$name
echo $message > proposal
cd ..
echo $name >> open

# Git won't shutup when adding files, so pipe everything to /dev/null
git add open >> /dev/null 2>&1
git add $name >> /dev/null 2>&1

git do-commit --quiet -m "Proposed: $name"

# Need to be back in the tree root so git can delete .tracking when we
# switch back to the proposal branch
cd ../..

git checkout --quiet $orig_head
git checkout -b --quiet proposals/$name

echo "Created Proposal: $name"