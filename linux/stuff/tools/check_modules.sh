#!/bin/sh
# Print Linux Kernel modules that do not belong to any of the packages.
# (c) 2009-2017 SliTaz - GNU General Public License.
#

. /lib/libtaz.sh

WOK=$(cd $(dirname $0) && pwd | sed 's/wok.*/wok/')
. $WOK/linux/receipt
BASEVER="${VERSION:0:3}"
src="$WOK/linux/source/linux-$VERSION"

cd $src
tmp=$WOK/${PACKAGE:-linux}/tmp
mkdir -p $tmp
rm -f $tmp/*

#===============================================================================

# Make temporal base modules list

kversion="$VERSION-slitaz"
modroot="$WOK/$PACKAGE/install/lib/modules/$kversion/kernel"
modlist="$tmp/modules.list"

list_modules() {
	found="$(find $modroot/$1 -type f)"
	if [ -z "$found" ]; then
		echo -e "\n\nError: $modroot/$1 does not exist.\n\n" >&2
		exit 1
	fi

	for module in $(echo "$found" | sed "s|.*$kversion/||"); do
		grep $module: "$modroot/../modules.dep"
	done | sed 's|^kernel/||; s| kernel/| |g; s|:||' | \
	tr ' ' $'\n' | sort -u
}

while read rule_name rule_value; do
	[ "$rule_name" != 'linux' ] && continue
	list_modules $rule_value >> "$modlist"
done < "$WOK/linux/stuff/split.rules"

#===============================================================================

echo
title 'Checking for Linux Kernel modules that do not belong to any of the packages'

# create a packaged modules list
{
	cat "$modlist"

	for i in $SPLIT; do
		cat $WOK/$i/taz/$i-*/files.list | sed 's|.*/kernel/||'
	done
} | grep '.ko.xz$' > $tmp/modules-packaged

# create a compiled modules list
sed 's|^kernel/||; s|$|.xz|' \
$WOK/linux/install/lib/modules/$VERSION-slitaz/modules.order > $tmp/modules-compiled

# compare the lists
awk '{
	if (FILENAME ~ "compiled")
		m[$0] = 1;
	else
		delete m[$0];
}
END {
	for (i in m) print i;
}' $tmp/modules-compiled $tmp/modules-packaged | tee $tmp/modules-unpackaged

if [ -s $tmp/modules-unpackaged ]; then
	footer "List saved to wok/linux/tmp/modules-unpackaged"
else
	_ 'All modules are packaged'
	echo
	rm $tmp/modules-unpackaged
fi

# Clean
rm "$modlist"
