#!/bin/sh

. git-sh-setup

# Tests to see if the given array contains the given value
contains() {
    search=$1
    shift
    array=$*
    if [[ ${array[@]} == *$search* ]]
    then
        for element in "${array[@]}"
        do
            if [[ $element == $search ]]
            then
                return 0
            fi
        done
    fi

    return 1
}

# Reads a header from a file
read_header()
{
    look_for=$1
    file=$2

    while IFS=: read key value
    do
        value=$(echo $value | sed 's/^\s*//;s/\s*$//')
        key=$(echo $key | tr '[:upper:]' '[:lower:]')

        if [ "$key" = "$look_for" ]
        then
            echo $value
            return 0
        fi
    done < $file

    return 1
}

# Finds the branch point of the given commit
find_branch_point()
{
    name=$1
    first=true
    explored=()

    # Find what this is based on
    for commit in $(git rev-list $name)
    do
        for branch in $(git branch --contains $commit | sed 's/\*//;s/ *//')
        do
            if test true = $first
            then
                explored+=("$branch")
                continue
            fi

            # Check if we've already inspected this branch. If we have it
            # obviously didn't yield anything, so we can skip it here
            if contains $branch $explored; then
                continue
            fi

            # Mark the branch as explored so we don't have to mess about
            # with it again
            explored+=("$branch")

            # Check if this commit is in a locked branch
            # If it is, we must be working of this
            locked=`git config --file .tracking/config branch.$branch.locked`
            if [ "$locked" = "true" ]; then
                echo $commit
                return 0
            fi

            # Check if this commit is in a proposal
            branch_head=`git rev-parse --verify $branch`
            if [ -d .tracking/proposals/$branch_head ]; then
                start=$(read_header start .tracking/proposals/$branch_head/proposal)

                if [ $? != 0 ]
                then
                    die "fatal: malformed proposal ($branch_head) is missing start header"
                fi

                if [ "$start" = "$commit" ] || ! git merge-base --is-ancestor $start $commit
                then
                    continue
                else
                    echo $commit
                    echo $branch_head
                    return 0
                fi
            fi
        done

        if test true = $first; then
            first=false
        fi
    done

    return 1
}