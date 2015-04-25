#!/bin/sh

test_description='Testing adding a contributor'

. ./test-lib.sh

make_expect()
{
    cat > expect <<EOF
User: User Name
Proposals: 0
Accepted: 0
Rejected: 0
Reviews: 0
Bad-Rejects: 0
Bad-Accepts: 0
Good-Accepts: 0
Good-Rejects: 0
EOF
}

test_expect_success 'Adding Defined User' '
    git legitimize &&
    git add-contributor --name "User Name" --email "email@example.net" &&
    git checkout tracking &&
    test -a .tracking/users/email_example.net &&
    make_expect &&
    test_cmp expect .tracking/users/email_example.net
'

test_expect_success 'Adding Current User' '
    git reset --hard HEAD~1 &&
    git checkout --orphan master &&
    git config user.name "User Name" &&
    git config user.email "email@example.net" &&
    git add-contributor &&
    git checkout tracking &&
    test -a .tracking/users/email_example.net &&
    make_expect &&
    test_cmp expect .tracking/users/email_example.net
'

test_expect_success 'Re-adding User' '
    git checkout --orphan master &&
    test_must_fail git add-contributor &&
    test $(git symbolic-ref -q --short HEAD) = "master"
'

test_done