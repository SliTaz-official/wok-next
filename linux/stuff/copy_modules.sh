#!/bin/sh
# copy_modules.sh: copy Linux Kernel modules for SliTaz GNU/Linux.
# GNU General Public License.
#

path="lib/modules/$VERSION-slitaz/kernel"

# Redefine variables for the Linux 64
if [ ${PACKAGE:0:7} == 'linux64' ]; then
	src="$WOK/linux64/source/tmp"
	install="$install/linux64"
	path="lib/modules/$VERSION-slitaz64/kernel"
fi

find_modules() {
	find $install/lib/modules/*-slitaz*/kernel/$1 -type f -exec basename {} \;
}

list_modules() {
	if [ -z "$(ls -d $install/lib/modules/*-slitaz*/kernel/$1 2>/dev/null)" ]; then
		echo -e "\n\nError: $1 does not exist.\n\n" >&2
		exit 1
	fi

	for tree in $1; do
		echo "Search modules for $tree..." >&2
		for module in $(find_modules $tree); do
			grep /$module: $install/lib/modules/*-slitaz*/modules.dep ||
			find $install/lib/modules/*-slitaz*/kernel/$tree -name $module
		done | awk '{ for (i = 1; i <= NF; i++)  print $i; }'
	done | sort | uniq | sed -e 's,.*slitaz[64]*/,,' -e 's,^kernel/,,' -e 's/:$//' | \
	while read module; do
		if grep -qs ^$module$ $src/../tmp/modules.list; then
			echo "  - $module" >&2
			continue
		fi
		if [ ! -f $install/lib/modules/*-slitaz*/kernel/$module ]; then
			(
				cd $install/lib/modules/*-slitaz*/kernel
				find -name $(basename $module)
			)
		else
			echo $module
			echo "  + $module" >&2
		fi
	done
}

copy_modules() {
	mkdir -p $fs/$path
	for i in $@; do
		list_modules $i | \
		while read module; do
			dir=$path/$(dirname $module)
			mkdir -p $fs/$dir
			cp -a $install/$path/$module $fs/$dir
		done
	done

	for i in $(cat $wanted_stuff/modules.list); do
		if [ -f $fs/$path/$i ]; then
			echo "Removing $i..."
			rm -f $fs/$path/$i
		fi
	done
}
