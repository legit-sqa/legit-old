#!/bin/sh

test_description='Testing the initialisation of legit'

. ./test-lib.sh

test_expect_success 'Tracking Branch Exists' '
    git legitimise &&
    git show-ref --quiet refs/heads/tracking &&
    git checkout tracking
'

test_expect_success '.tracking directory exists' '
    test -d .tracking
'

test_expect_success 'config file exists' '
    test -a .tracking/config
'

test_expect_success 'proposal directory exists' '
    test -d .tracking/proposals &&
    test -a .tracking/proposals/open &&
    test -a .tracking/proposals/pending
'

test_done