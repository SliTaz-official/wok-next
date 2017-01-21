#!/bin/sh
# copy_modules.sh: copy Linux Kernel modules for SliTaz GNU/Linux.
# GNU General Public License.
#

kversion="$VERSION-slitaz"
modroot="$install/lib/modules/$kversion/kernel"
modlist="/tmp/modules.list.$$"

# Redefine variables for the Linux 64
if [ ${PACKAGE:0:7} == 'linux64' ]; then
	src="$WOK/linux64/source/tmp"
	install="$install/linux64"
	kversion="$VERSION-slitaz64"
fi


list_modules() {
	found="$(find $modroot/$1 -type f)"
	if [ -z "$found" ]; then
		echo -e "\n\nError: $1 does not exist.\n\n" >&2
		exit 1
	fi

	echo "Search modules for $1..." >&2
	for module in $(echo "$found" | sed "s|.*$kversion/||"); do
		grep $module: "$install/lib/modules/$kversion/modules.dep"
	done | sed 's|^kernel/||; s| kernel/| |g; s|:||' | \
	awk '{ for (i = 1; i <= NF; i++)  print $i; }' | \
	sort -u | \
	while read module; do
		if grep -qs ^$module$ "$modlist"; then
			echo "  - $module" >&2
			continue
		else
			echo "  + $module" >&2
			echo $module
		fi
	done
}


#
# Main
#

# A. Build list of "restricted" modules: all these modules should be only in the "linux" package

# A.1. Builtin modules
awk '{sub(/^kernel\//, ""); print $1 ".xz"}' "$install/lib/modules/$kversion/modules.builtin" > "$modlist"

# A.2. Using split.rules for the "linux" rules
case $PACKAGE in
	linux|linux-libre|linux64)
		# make exception for the base "linux" package
		;;
	*)
		while read rule_name rule_value; do
			[ "$rule_name" != 'linux' ] && continue
			list_modules $rule_value >> "$modlist" 2>/dev/null
		done < "${wanted_stuff:-$stuff}/split.rules"
		;;
esac

# A.3. If package depends on other package - make these modules "restricted" (excluded) too
if [ "$DEPENDS" != "$WANTED" ]; then
	for i in $DEPENDS; do
		if [ "$i" != "$WANTED" ]; then
			pkg_subname=${i#linux-libre-}
			pkg_subname=${pkg_subname#linux*-}

			while read rule_name rule_value; do
				[ "$pkg_subname" != "$rule_name" ] && continue
				list_modules $rule_value >> "$modlist" 2>/dev/null
			done < "${wanted_stuff:-$stuff}/split.rules"
		fi
	done
fi


# B. Copy modules from the linux $install

# B.1. Get the name of the rule
#      linux{,-libre,64}-subname -> subname
case $PACKAGE in
	linux-libre|linux64|linux) pkg_subname="linux";;
	linux-libre-*) pkg_subname="${PACKAGE#linux-libre-}";;
	linux64-*)     pkg_subname="${PACKAGE#linux64-}";;
	linux-*)       pkg_subname="${PACKAGE#linux-}";;
esac

# B.2. Process rules, copy modules
while read rule_name rule_value; do
	[ "$pkg_subname" != "$rule_name" ] && continue

	list_modules $rule_value | \
	while read module; do
		dir=lib/modules/$kversion/kernel/$(dirname $module)
		mkdir -p $fs/$dir
		cp -a $modroot/$module $fs/$dir
	done
done < "${wanted_stuff:-$stuff}/split.rules"

# B.3. Clean
rm "$modlist"


# C. Compare with the previous version: use the --diff (for example, `cook linux-acpi --diff`)

if [ -n "$diff" ]; then
	lzcat /var/lib/tazpkg/files.list.lzma | grep ^$PACKAGE: | awk -F/ '{print $NF}' | sort > /tmp/old
	find $fs -type f                                        | awk -F/ '{print $NF}' | sort > /tmp/new
	diff -d -U0 /tmp/old /tmp/new | sed '/^---/d; /^+++/d; /^@@/d; /\.ko\./!d' > $WOK/$PACKAGE/diff.diff
fi
