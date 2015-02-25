#!/bin/sh

. git-legit-setup

name=
email=
while test $# != 0
do
    case "$1" in
        --name)
            shift
            name=$1

            if test -z "$name"
            then
                echo "--name requires a name"
                usage
            fi
            ;;
        --email)
            shift
            email=$1

            if test -z "$email"
            then
                echo "--email requires an email"
                usage
            fi
            ;;
        *)
            usage
    esac
    shift
done

if test -z "$name"
then
    name=$(git config user.name)

    if test -z "$name"
    then
        die "fatal: Couldn't find a username"
    fi
fi

if test -z "$email"
then
    email=$(git config user.email)

    if test -z "$email"
    then
        die "fatal: Couldn't find a user email"
    fi
fi

require_clean_work_tree
cd_to_toplevel

user_file=${email//@/_}
orig_head=`git symbolic-ref -q --short HEAD`
git checkout --quiet tracking

if ! test -d .tracking/users
then
    mkdir .tracking/users
fi

if test -a .tracking/users/$user_file
then
    die "This user already exists in the system"
fi

touch .tracking/users/$user_file

cat > .tracking/users/$user_file <<EOF
User: $name
Proposals: 0
Accepted: 0
Rejected: 0
Reviews: 0
Bad-Rejects: 0
Bad-Accepts: 0
Good-Accepts: 0
Good-Rejects: 0
EOF

git add .tracking/users/$user_file>> /dev/null 2>&1

git commit --quiet -m "Added User: $name <$email>"

git checkout --quiet $orig_head

echo "Added User: $name <$email>"