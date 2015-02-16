#!/bin/sh

orig_head=`git symbolic-ref -q --short HEAD`
stashed=0

if ! git show-ref refs/heads/tracking; then
    echo "Creating tracking branch..."
    git checkout --orphan tracking

    echo "Cleaning workspace..."
    git rm --force --quiet -r .
else
    if git diff-index --quiet HEAD; then
        git stash
        stashed = 1
    fi

    git checkout tracking
fi

echo "Initializing tracking directory..."
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

git add .tracking/ > /dev/null
git commit -m 'Initialized .tracking branch' > /dev/null

echo "Restoring workspace..."

if ! git show-ref refs/heads/$orig_head; then
    git checkout --orphan $orig_head

    git rm --force --quiet -r .
else
    git checkout $orig_head > /dev/null

    if stashed; then
        git stash pop
    fi
fi