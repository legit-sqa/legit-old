#!/bin/sh

. git-legit-setup

do_merge()
{
    local name=$1
    local branch=$2

    git checkout $branch --quiet

    if git merge $name --quiet --no-ff --no-commit > /dev/null 2>&1
    then
        git-commit --quiet -m "Merged: $name"

        git checkout tracking --quiet

        sed "/$name/d" .tracking/proposals/pending | cat > .tracking/proposals/pending
        git add .tracking/proposals/pending >> /dev/null 2>&1

        replace_header Status Merged .tracking/proposals/$name/proposal
        git add .tracking/proposals/$name/proposal >> /dev/null 2>&1

        git commit --quiet -m "Merged: $name"
    else
        return 1
    fi

    return 0
}

# Get the commit message
message=
user=$(git config user.email)
user=${user//@/_}
result=
while test $# != 0
do
    case "$1" in
        -m)
            shift

            # Get the message, but trim whitespace from it
            message=`echo $1 | sed 's/^\s*//;s/\s*$//'`

            # This will be blank if the user either failed to provide a
            # message, or if it was only whitespace (which we reject)
            if [ -z "$message" ]; then
                usage
            fi
            shift
            ;;
        --approve)
            result="approve" ;;
        --reject)
            result="reject" ;;
        *)
            usage
    esac
    shift
done

if ! test -n "$result"
then
    usage
fi

if ! test -n "$user"
then
    die "fatal: no user was found. Set one in git config"
fi

if ! git permissions review
then
    die
fi

# People need to specify a message!
if [ ! -n "$message" ]; then
    echo "# Please enter the review message. Lines starting" > .git/REVIEW_EDITMSG
    echo "# with '#' will be ignored, and an empty message aborts the proposal." >> .git/REVIEW_EDITMSG

    git_editor .git/REVIEW_EDITMSG

    # Remove comments, whitespace and blank lines
    message=`sed '/\s*#/d;s/^\s*//;s/\s*$//;/./,$!d' .git/REVIEW_EDITMSG`

    if [ -z "$message" ]; then
        echo "Aborting because of empty message"
        exit 0
    fi
fi

# Has this repo been legitimised?
if ! git show-ref --quiet refs/heads/tracking; then
    die "fatal: no tracking branch exists"
fi

require_clean_work_tree 'make a review'

# Check we're not in a locked branch, or the tracking branch
orig_head=`git symbolic-ref -q --short HEAD`
if [ "$orig_head" = "tracking" ]; then
    die "fatal: you are in the tracking branch. Please checkout the
the branch you wish to review."
fi

# The commit at the head of the proposal is used as it's ID
name=`git rev-parse --verify HEAD`

# Let's do this
git checkout --quiet tracking

# Hash collisions shouldn't happen...
if [ ! -d .tracking/proposals/$name ]; then
    die "fatal: this proposal doesn't exist"
fi

if [ -e .tracking/proposals/$name/$user ]
then
    die "fatal: you have already reviewed this proposal"
fi

cd .tracking/proposals/$name

vote_count=$(read_header votes proposal)

echo "Reviewer: $(git config user.name) <$(git config user.email)>" > $user
echo "Reviewed-at: $(date -R)" >> $user

if [[ "reject" == "$result" ]]
then
    echo "Result: Reject" >> $user
    vote_count=$(expr $vote_count - 1)
else
    echo "Result: Accept" >> $user
    vote_count=$(expr $vote_count + 1)
fi

echo "" >> $user
echo "$message" >> $user

replace_header Votes $vote_count proposal

git add $user >> /dev/null 2>&1
git add proposal >> /dev/null 2>&1

cd ../../users/

replace_header Reviews $(expr $(read_header reviews $user) + 1) $user

git add $user >> /dev/null 2>&1

git-commit --quiet -m "Reviewed: $name"
echo "Successfully Reviewed"

cd ..

voteThreshold=$(git config --file config general.voteThreshold)

if test $vote_count -ge $voteThreshold
then
    echo "The proposal has reached the required votes. Automatically approving..."
    replace_header Status Accepted proposals/$name/proposal

    sed '/$name/d' proposals/open | cat > proposals/open
    echo $name >> proposals/pending
    git add proposals/$name/proposal >> /dev/null 2>&1
    git add proposals/open >> /dev/null 2>&1
    git add proposals/pending >> /dev/null 2>&1

    for file in $(find proposals/$name/* -printf %f\\n)
    do
        if [[ $file != "proposal" ]] && [ -n "$file" ]
        then
            result=$(read_header result proposals/$name/$file)

            if [[ $result == "Reject" ]]
            then
                header1="Bad-Rejects"
                header2="bad-rejects"
            else
                header1="Good-Accepts"
                header2="good-accepts"
            fi

            file="./users/$file"

            replace_header $header1 $(expr $(read_header $header2 $file) + 1) $file

            git add $file >> /dev/null 2>&1
        fi
    done

    git-commit --quiet -m "Approved: $name"

    cd ..

    start=$(read_header start .tracking/proposals/$name/proposal)
    for branch in $(git branch --contains $start | sed 's/\*//;s/ *//')
    do
        # Check if this commit is in a locked branch
        locked=`git config --file .tracking/config branch.$branch.locked`
        if [ "$locked" = "true" ]
        then
            echo "Attempting to automatically merge..."
            do_merge $name $branch

            for ext in $(read_header extended-by .tracking/proposals/$name/proposal)
            do
                if [ $(read_header status .tracking/proposals/$ext/proposal) = "Accepted" ]
                then
                    do_merge $ext $branch
                fi
            done

            break
        fi
    done
elif test $vote_count -le $(expr $voteThreshold \* -1)
then
    replace_header Status Rejected ./proposals/$name/proposal
    sed '/$name/d' proposals/open | cat > ./proposals/open

    git add proposals/$name/proposal >> /dev/null 2>&1
    git add proposals/open >> /dev/null 2>&1

    for file in $(find proposals/$name/* -printf %f\\n)
    do
        if [[ $file != "proposal" ]] && [ -n "$file" ]; then
            result=$(read_header result proposals/$name/$file)

            if test $result = "Reject"
            then
                header1="Good-Rejects"
                header2="good-rejects"
            else
                header1="Bad-Accepts"
                header2="bad-accepts"
            fi

            file="./users/$file"
            replace_header $header1 $(expr $(read_header $header2 $file) + 1) $file

            git add $file >> /dev/null 2>&1
        fi
    done

    git-commit --quiet -m "Rejected: $name"

    cd ..
fi

git checkout --quiet $orig_head