#!/bin/sh
# check-split.sh: check split quality for the Linux modules
# Make the three-column Markdown-friendly table representing all the modules.
# Column #1: module path/name.ko.xz
# Column #2: package(s), which owns module
# Column $3: module description (if any)

. /lib/libtaz.sh
WOK='/home/slitaz/wok'
tmp="$WOK/linux/tmp"; mkdir -p $tmp
out="$tmp/modules.split"
. $WOK/linux/receipt

# List of all the modules
order="$WOK/linux/install/lib/modules/$VERSION-slitaz/modules.order"
maxlen=$(wc -L $order | cut -d' ' -f1)
maxlen1=$(( maxlen - 7 + 2 )) # leading "kernel/" will be removed (-7), "`...`" will be added (+2)
hline=$(printf "%${maxlen1}s" '' | tr -c '\n' '-')

# First column: module name with local path
sort $order | awk -vhline=$hline '
BEGIN {
	printf("%-'$(( maxlen1 + 3))'s | \n", "Module path/name.ko.xz");
	printf("%s----|-\n", hline);
}
{
	sub("kernel/", "");
	gsub("/", "@");       # change "/" to "@" to easy use sed in the next step
	printf("%-'$maxlen1's | \n", "`" $0 "`");
}' > $out


# Second column: package name(s) for the module
for i in linux $SPLIT; do
	action "Processing $i..."
	while read f; do
		case $f in
			*.ko.xz)
				fshort=${f#*/kernel/}
				fshort=$(echo $fshort | sed 's|/|@|g')
				fshort=${fshort%.xz}
				sed -i "/$fshort/ s|$|$i |" $out
				;;
		esac
	done < "$WOK/$i/taz/$i-$VERSION/files.list"
	status
done


maxlen2=$(wc -L $out | cut -d' ' -f1)
hline=$(printf "%$(( maxlen2 - maxlen1 - 3 ))s" '' | tr -c '\n' '-')
mv $out $out.tmp
awk -vhline=$hline '{
	if (NR==1)
		printf("%-'$(( maxlen2 + 3 ))'s |\n", $0 "Package(s)");
	else if (NR==2)
		printf("%s-|\n", $0 hline);
	else
		printf("%-'$maxlen2's |\n", $0);
}' $out.tmp > $out
rm $out.tmp


tr '@' '/' < "$out" > "$out.tmp"; mv "$out.tmp" "$out"
sed -i 's|\.ko` |.ko.xz` |' "$out"


# Third column: descriptions
action "Getting descriptions..."
IFS=$'\n'
while read i; do
	echo -n "$i"
	module=${i%\`*}; module=${module#\`}
	if [ -f "$WOK/linux/install/lib/modules/$VERSION-slitaz/kernel/$module" ]; then
		info=$(modinfo -d $WOK/linux/install/lib/modules/$VERSION-slitaz/kernel/$module | tr '\n' ' ' | sed 's| $||')
		[ -n "$info" ] && info=" $info"
		echo "$info"
	else
		echo
	fi
done < "$out" > "$out.tmp"
unset IFS

awk '{
	if (NR==1)
		printf("%s\n", $0 " Description");
	else if (NR==2)
		printf("%s\n", $0 "------------");
	else
		print;
}' "$out.tmp" > "$out"
rm "$out.tmp"
status
footer "File: $out"
