#!/bin/sh

# Get the commit message
message=
while :
do
    case "$1" in
        -m)
            shift
            message=$1
            ;;
        *)
            break
    esac
    shift
done

# People need to specify a message!
if [ ! -n "$message" ]; then
     >&2 echo "fatal: Please supply a message"
    exit -5
fi

# Has this repo been legitimised?
if ! git show-ref --quiet refs/heads/tracking; then
    >&2 echo "fatal: no tracking branch exists"
    exit -1
fi

# Check we don't have changes in the working tree
changes=`git diff-index --quiet HEAD --`
if [ -n "$changes" ]; then
    >&2 echo "fatal: you have unstashed changes in your working tree"
    exit -2
fi

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

git commit --quiet -m "Proposed: $name"

# Need to be back in the tree root so git can delete .tracking when we
# switch back to the proposal branch
cd ../..

git checkout --quiet $orig_head
git checkout -b --quiet proposals/$name

echo "Created Proposal: $name"