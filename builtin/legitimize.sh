#!/bin/sh

orig_head=`git symbolic-ref -q --short HEAD`
stashed=0

if git diff-index --quiet HEAD; then
    git stash > /dev/null
    stashed = 1
fi

# If we don't have a tracking branch, we must make one
if ! git show-ref refs/heads/tracking; then
    git checkout --orphan tracking > /dev/null

    # Git only allows us to clean up when there's something to delete
    if git show-ref refs/heads/$orig_head; then
        git rm --force --quiet -r . > /dev/null
    fi
else
    git checkout tracking > /dev/null
fi

# Init some stuff
if [ ! -d .tracking/ ]
    then
    mkdir .tracking/
fi
cd .tracking/

if [ ! -a config ]
    then
    touch config
fi

if [ ! -d proposals/ ]
    then
    mkdir proposals/
fi
cd proposals/

if [ ! -a open ]
    then
    touch open
fi
if [ ! -a pending ]
    then
    touch pending
fi

cd ../..

# Commit this initialisation to the tracking branch
git add .tracking/ > /dev/null
git commit -m 'Initialized .tracking branch' > /dev/null

# If this is a new repository, it's possible that the branch we were
# just in is actually empty (and therefore doesn't exist). If that's the
# case - make one
if ! git show-ref refs/heads/$orig_head; then
    git checkout --orphan $orig_head > /dev/null

    git rm --force --quiet -r . > /dev/null
else
    git checkout $orig_head > /dev/null

    if stashed; then
        git stash pop > /dev/null
    fi
fi