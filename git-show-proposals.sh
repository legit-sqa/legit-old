#!/bin/sh

. git-sh-setup

require_work_tree 
cd_to_toplevel

proposals=`git for-each-ref --format='%(objectname)' refs/heads/proposals`

echo "$proposals" | while read proposal; do
    git checkout --quiet tracking -- .tracking/proposals/$proposal

    cat .tracking/proposals/$proposal/proposal
done