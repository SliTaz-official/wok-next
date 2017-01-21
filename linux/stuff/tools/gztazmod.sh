#!/bin/sh
# gztazmod.sh: Compress Linux Kernel modules for SliTaz GNU/Linux.
# 2007-2017 <pankso@slitaz.org> - GNU General Public License.
#
. /lib/libtaz.sh

# We do our work in the Kernel version modules directory.
if [ -z "$1" ] ; then
	newline
	_ 'Usage: %s path/to/kernel-version' "$(basename $0)"
	newline
	exit 1
fi

if [ ! -r "$1" ] ; then
	newline
	_ 'Error: %s does not exist.' "$1"
	newline
	exit 1
fi

cd $1

# Script start.
newline
_ 'Starting %s to build compressed Kernel modules...' "$(basename $0)"
newline

# Find all modules.
action 'Searching all modules to compress them...'
find . -name '*.ko' -exec xz '{}' \; 2>/dev/null
status
find . -name '*.ko' -exec rm '{}' \;

# Build a new temporary modules.dep.
action 'Building tmp.dep...'
sed    's/\.ko.[xg]z/.ko/g' modules.dep > tmp.dep
sed -i 's/\.ko.[xg]z/.ko/g' tmp.dep
sed -i 's/\.ko/.ko.xz/g'    tmp.dep
status

# Destroy original modules.dep
action 'Destroying modules.dep...'
rm modules.dep
status

# Remove tmp.dep to modules.dep.
action 'Moving tmp.dep to modules.dep...'
mv tmp.dep modules.dep
status

# Script end.
newline
_ 'Kernel modules %s are ready.' "$(basename $1)"
newline
