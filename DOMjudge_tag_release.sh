#!/bin/bash

set -eu

main=master

DOWNLOAD_RELEASE_SCRIPT=""

notify_channel () {
    logger "$1"
    # Optionally notify the Slack channel
    # that a build has been triggered
}

process_tag () {
    TAG="$1"
    NUMB="[0-9]+"
    DOT="\."
    RELEASE="$NUMB$DOT$NUMB$DOT$NUMB"
    OPTRC="((RC|rc)[0-9])?"
    if [[ $TAG =~ ^$RELEASE$OPTRC$ ]]; then
       # TODO: check if the file already exists
       if [ -f "$RELEASE_DIR/domjudge-$TAG.tar.gz" ]; then
           # Tag is already handled
           return 0
       # To find the signer key of a earlier tag:
       # gpg --search 780355B5EA6BFC8235A99C4B56F61A79401DAC04
       # And if one trusts the internet to be correct
       # gpg --recv-keys 780355B5EA6BFC8235A99C4B56F61A79401DAC04
       set +e # Some tags are not signed
       if git verify-tag $TAG; then
           set -e
           echo "Valid $TAG"
           # At this point the tarball should already be locally tested
           ./make_release "$TAG"
           notify_channel "Tarball finished ($TAG)."
       else
           # In this case we should probably alert on such a tag?
           notify_channel "Untrusted tag ($TAG)"
       fi
    fi
}

# Reset to main branch
git checkout $main

while read -r tag; do
    #echo "Handling tag: $tag"
    process_tag "$tag"
done <<< "$(git tag)"

