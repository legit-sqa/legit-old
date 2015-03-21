#!/bin/sh

. git-legit-setup

user=$(git config user.email)
user=${user//@/_}
if ! test -n "$user"
then
    die "fatal: no user was found. Set one in git config"
fi

cd_to_toplevel

git checkout tracking -- .tracking/config
git checkout tracking -- .tracking/users/$user

if [ $? != 0 ]
then
    die "fatal: The user isn't in the system"
fi

read_required_values $1

file=".tracking/users/$user"
proposals=$(read_header proposals $file)
accepted=$(read_header accepted $file)
rejected=$(read_header rejected $file)
reviews=$(read_header reviews $file)
bad_accepts=$(read_header bad-accepts $file)
bad_rejects=$(read_header bad-rejects $file)
good_accepts=$(read_header good-accepts $file)
good_rejects=$(read_header good-rejects $file)

can_do=false

do_test()
{
    header=$1
    value=$2
    threshold=$3

    if test $value -lt $threshold
    then
        die "Fatal: Not enough $header"
    fi
}

do_test "Total Proposals" $proposals $req_total_proposals
do_test "Proposals" $(expr $accepted - $rejected) $req_proposals
do_test "Accepted Proposals" $accepted $req_accepted

good_reviews=$(expr $good_accepts + $good_rejects)
bad_reviews=$(expr $bad_accepts + $bad_rejects)
do_test "Total Reviews" $reviews $req_total_reviews
do_test "Reviews" $(expr $good_reviews - $bad_reviews) $req_reviews
do_test "Good Accepts" $good_accepts $req_good_accepts
do_test "Good Rejects" $good_rejects $req_good_rejects

git rm --quiet -f -r .tracking