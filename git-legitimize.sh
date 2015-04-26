#!/bin/sh

. git-legit-setup.sh

orig_head=`git symbolic-ref -q --short HEAD`
stashed=0

# Check that the current branch exists - so we can check if it has
# unstashed changed
if git show-ref --quiet refs/heads/$orig_head; then
    # Check if we need to stash some changes
    if git diff-index --quiet HEAD --; then
        git stash > /dev/null
        stashed=1
    fi
fi

# If we don't have a tracking branch, we must make one
if ! git show-ref --quiet refs/heads/tracking; then
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
git do-commit --quiet -m 'Initialized .tracking branch'

return_to_orig_head