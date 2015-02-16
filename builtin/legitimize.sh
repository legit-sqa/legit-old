#!/bin/sh

exists=`git show-ref refs/heads/tracking`

if [ ! -n "$exists" ]
    then

    current_branch=`git symbolic-ref -q --short HEAD`

    echo "Creating tracking branch..."
    git checkout --orphan tracking

    echo "Cleaning workspace..."
    git rm --force --quiet -r .

    echo "Initialising tracking directory..."
    mkdir .tracking/
    cd .tracking/
    mkdir users/
    mkdir proposals/
    touch proposals/open
    touch proposals/pending

    cd ..
    git add .tracking/ > /dev/null
    git commit -m 'Initialised .tracking branch' > /dev/null

    echo "Restoring workspace..."
    git checkout $current_branch > /dev/null
fi