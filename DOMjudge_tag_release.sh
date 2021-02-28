#!/bin/bash

set -eu

. ./release.env

DOWNLOAD_RELEASE_SCRIPT=""

notify_channel () {
    logger "$1"
    # Optionally notify the Slack channel
    # that a build has been triggered
}

docs_version () {
    VERS_MIN="${1%.*}"
    TMPFILE="/tmp/versions.json"
    ORIGFILE="$DOCS_DIR/versions.json"
    MAIN_PAGE="$DOCS_DIR/index.html"
    jq '. - ["master"] + ["'"$VERS_MIN"'","master"]' < "$ORIGFILE" > "$TMPFILE"
    mv "$TMPFILE" $ORIGFILE
    sed "s/manual\/[[:digit:]].[[:digit:]]/manual\/$VERS_MIN/" "$MAIN_PAGE"
}

test_tarball () {
    # Happens as current side effect of docker build
    true
}

build_deb () {
    # Not sure if this should happen on the server?
    true
}

build_docker () {
    # Create on: https://gitlab.com/DOMjudge/domjudge-packaging/-/settings/ci_cd
    curl -X POST \
         -F token="$TOKEN" \
         -F "ref=master" \
         -F "variables[DOMJUDGE_VERSION]=$1" \
         https://gitlab.com/api/v4/projects/24097565/trigger/pipeline
}

process_tag () {
    if [ ! -f "$RELEASE_DIR/$1" ]; then
        notify_channel "Found new tag: ($1)."
        if [ -z $DOWNLOAD_RELEASE_SCRIPT ]; then
            wget "$RELEASE_WEB"
            DOWNLOAD_RELEASE_SCRIPT="done"
        fi
        if git tag -v "$1"; then
            notify_channel "Untrusted tag ($1)"
            exit 1
        fi
        ./make_release "$1"
        rsync -rva "./$1"* "$RELEASE_DIR/"
        notify_channel "Tarball finished ($1)."
        test_tarball "$1"
        build_docker "$1"
        build_deb "$1"
        if [ "$2" -eq 1 ]; then
            # Release on the main branch,
            # This is the latest release
            #
            # TODO: Handle website update
            docs_version "$tag"
            true
        fi
    fi
}

process_branch () {
    while read -r tag; do
        echo "Handling tag: $tag in branch: $1"
        process_tag "$tag"
    done <<< "$(git tag)"
}

# Reset to master
git checkout master

# The main branch is special as we also update the website
process_branch origin/master 1

while read -r branch; do
    process_branch "$branch" 0
done <<< "$(git branch -r)"

