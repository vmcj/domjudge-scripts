#!/bin/bash

. release.env

for i in `git tag | grep 7`; do git tag -d $i; done

DOWNLOAD_RELEASE_SCRIPT=""

notify_channel () {
    # Optionally notify the Slack channel
    # that a build has been triggered
}

test_tarball () {
    # Happens as current side effect of docker build
}

build_deb () {
    # Not sure if this should happen on the server?
}

build_docker () {
    # Create on: https://gitlab.com/DOMjudge/domjudge-packaging/-/settings/ci_cd
    curl -X POST \
         -F token=$TOKEN \
         -F "ref=master" \
         -F "variables[DOMJUDGE_VERSION]=$1" \
         https://gitlab.com/api/v4/projects/24097565/trigger/pipeline
}

process_tag () {
    if [ ! -f $RELEASE_DIR/$1 ]; then
        notify_channel "Found new tag: ($1)."
        if [ -z $DOWNLOAD_RELEASE_SCRIPT ]; then
            wget $RELEASE_WEB
            $DOWNLOAD_RELEASE_SCRIPT="done"
        fi
        ./make_release $1
        rsync -rva ./$1* $RELEASE_DIR/
        notify_channel "Tarball finished ($1)."
        test_tarball $1
        build_docker $1
        build_deb $1
        if [ $2 =eq 1 ]; then
            # Release on the main branch,
            # This is the latest release
            #
            # TODO: Handle website update
        fi
    fi
}

process_branch () {
    while read tag
    do
        echo "Handling tag: " $tag " in branch: " $1
        process_tag $tag
    done <<< $(git tag)
}

# Reset to master
git checkout master

process_branch origin/master 1

while read branch
do
    process_branch $branch 0
done <<< $(git branch -r | grep "origin")

