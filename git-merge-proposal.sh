#!/bin/sh

. git-legit-setup

# Has this repo been legitimised?
if ! git show-ref --quiet refs/heads/tracking; then
    die "fatal: no tracking branch exists"
fi

# Check we're not in a locked branch, or the tracking branch
orig_head=`git symbolic-ref -q --short HEAD`
if [ "$orig_head" = "tracking" ]; then
    die "fatal: you are in the tracking branch. Please checkout the
the branch you wish to review."
fi

if test -a .git/MERGE_HEAD
then
    merge=$(cat .git/MERGE_HEAD)
    git do-commit -m "Merged"
    git checkout -b proposals/merge
    git propose --is-merge $merge -m "Merge"
    git checkout $orig_head
    git reset --hard HEAD~1
    exit 0
fi

# The commit at the head of the proposal is used as it's ID
name=`git rev-parse --verify HEAD`

# Let's do this
git checkout --quiet tracking

# Hash collisions shouldn't happen...
if [ ! -d .tracking/proposals/$name ]; then
    die_neatly "fatal: this proposal doesn't exist"
fi

if test $(read_header status .tracking/proposals/$name/proposal) != "Accepted"
then
    die_neatly "fatal: this proposal cannot be merged"
fi

if merge $name keep
then
    echo "Automatic Merge Successful"
else
    echo "Automatic Merge Failed"
fi

