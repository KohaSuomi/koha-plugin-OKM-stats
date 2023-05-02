#!/bin/sh
die() { echo "$@"; exit 1 ; }

test "$(whoami)" = "koha" || die "You are not 'koha'."
expr "$(pwd)" : ".*/koha-plugin-.*" > /dev/null || die "Not a plugin dir."
test -d "./Koha/Plugin" || die "No ./Koha/Plugin directory, are you sure this is a plugin dir?"

mkdir -p $KOHA_PATH/misc/cronjobs/plugins
for cronjobdir in $(find $(pwd) -name cronjobs); do
    ln -svf $cronjobdir/* $KOHA_PATH/misc/cronjobs/plugins
done
