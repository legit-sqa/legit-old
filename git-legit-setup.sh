#!/bin/sh

. git-sh-setup

return_to_orig_head()
{
    # If this is a new repository, it's possible that the branch we were
    # just in is actually empty (and therefore doesn't exist). If that's the
    # case - make one
    if ! git show-ref --quiet refs/heads/$orig_head; then
        git checkout --orphan $orig_head > /dev/null

        git rm --force --quiet -r . > /dev/null
    else
        git checkout $orig_head > /dev/null

        if $stashed; then
            git stash pop > /dev/null
        fi
    fi
}

die_neatly()
{
    return_to_orig_head
    die $1
}

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
    return_val=1


    while IFS=: read key value
    do
        value=$(echo $value | sed 's/^\s*//;s/\s*$//')
        key=$(echo $key | tr '[:upper:]' '[:lower:]')

        if [ ! -n "$key" ]
        then
            break
        fi

        if [ "$key" = "$look_for" ]
        then
            echo $value
            return_val=0
        fi
    done < $file

    return $return_val
}

replace_header()
{
    header=$1
    value=$2
    file=$3

    cat $file | sed -r "s/^$header:.+\$/$header: $value/I" | cat > $file
}

append_header()
{
    header=$1
    value=$2
    file=$3

    cat $file | sed -r "0,/^$/s//$header: $value\n/" | cat > $file
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

# Parses config files 
read_required_values()
{
    # Overall Amounts
    req_total_proposals=0 # Total amount of proposals
    req_total_reviews=0   # Total amount of reviews
    req_proposals=0 # Accepted - Rejected Proposals
    req_reviews=0 # Good - Bad Reviews

    # Specific Amounts
    req_accepted=0     # Number of accepted proposals
    req_good_reviews=0 # Number of reviews with the correct answer
    req_good_accepts=0
    req_good_rejects=0

    local items=("$1:1")
    local i=0

    while test $i != ${#items[@]}
    do
        local item=(${items[$i]//:/ })
        local multiplier=${item[1]}

        item=${item[0]}
        i=$(expr $i + 1)

        for part in $(git config --file .tracking/config score.$item)
        do
            part=(${part//:/ })

            local rule=${part[0]}
            local num=${part[1]}

            if [ -z "$num" ] || [ "$num" -le 0 ]
            then
                num=1
            fi

            local value=$(expr $num \* $multiplier)

            case $rule in
                proposals|reviews|total-proposals|total-reviews|accepted|good-reviews|good-accepts|good-rejects)
                    rule="req_${rule//-/_}"
                    eval "$rule=\$(expr \${!rule} + $value)"
                    ;;
                *)
                    items+=("$rule:$value")
                    ;;
            esac
        done
    done
}