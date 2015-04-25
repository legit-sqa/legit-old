#!/bin/sh

test_description='Testing proposals'

. ./test-lib.sh

setup()
{
    git legitimize
    touch foo
    git add foo
    git do-commit -m "Initial Commit"
    git checkout tracking
    cat > .tracking/config <<EOF
[branch "master"]
    locked=true
EOF
    git add .tracking/config
    git do-commit -m "CONFIG"
    git checkout master
}

setup2()
{
    git reset --hard
    git add-contributor
    git checkout -b prop
    touch bar
    git add bar
    git do-commit -m "Test"
}

test_expect_success 'Making a proposal without a defined user' '
    setup && 
    test_must_fail git propose -m "Test" &&
    test $(git symbolic-ref -q --short HEAD) = "master"
'

test_expect_success 'Making a proposal without being a contributor' '
    git config user.name "User Name" &&
    git config user.email "email@example.net" &&
    touch foo &&
    test_must_fail git propose -m "Test"
    test $(git symbolic-ref -q --short HEAD) = "master"
'

test_expect_success 'Making a proposal without being a contributor' '
    setup2 &&
    git propose -m "Test"
'

test_done