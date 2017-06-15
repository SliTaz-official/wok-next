#!/bin/sh
# up-linux: update versions of all the packages depending on the Linux version

. /lib/libtaz.sh

WOK=$(cd $(dirname $0) && pwd | sed 's/wok.*/wok/')
. $WOK/linux/receipt

action 'Update packages version to %s...' "$VERSION"
for i in $SIBLINGS; do
	sed -i "s|^VERSION=.*$|VERSION=\"$VERSION\"|" $WOK/$i/receipt
done
status
