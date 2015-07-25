#!/bin/sh
#
# Scanner CGI interface - Scan documents via a browser
#
# (C) 2015 SliTaz GNU/Linux - BSD License
#

# Common functions from libtazpanel
. lib/libtazpanel
get_config

#------
# menu
#------

case "$1" in
	menu)
		TEXTDOMAIN_original=$TEXTDOMAIN
		export TEXTDOMAIN='sane'

		cat <<EOT
<li><a data-icon="text" href="sane.cgi"$(groups | grep -q scanner ||
echo ' data-root')>$(_ 'Scanner')</a></li>
EOT
		export TEXTDOMAIN=$TEXTDOMAIN_original
		exit
esac

TITLE="$(_ 'TazPanel - Hardware') - $(_ 'Scanner')"

inrange() {
	local n=$1
	[ $1 -lt $2 ] && n=$2
	[ $1 -gt $3 ] && n=$3
	echo $n
}
    
getgeometry() {
	CMD=""
	for i in l t x y ; do
		j=$(inrange $(xPOST geometry_$i) $(xPOST ${i}_min) $(xPOST ${i}_max))
		eval "geometry_$i=$j"
		CMD="$CMD -$i $j"
# convert -crop XxY+L+T -resize XxY
	done
	for i in mode source contrast brightness ; do
		[ "$(xPOST $i)" ] && CMD="$CMD --$i '$(xPOST $i)'"
	done
	resolution=${1:-0}
	if [ $resolution -eq 0 ]; then
		resolution=$(xPOST res_min)
		width=$(GET width)
		[ ${geometry_x:-0} -le 0 ] && geometry_x=$(xPOST x_max)
		while [ $((${resolution:=150} * ${geometry_x%.*})) -lt ${width:-8192} ]; do
			resolution=$(($resolution * 2))
		done
	fi
	[ -d tmp ] || ln -s /tmp tmp
	case "$device" in
	fake*)	echo "cat /usr/share/images/slitaz-background.jpg" ;;
	*)	echo "scanimage -d '$(echo $device | sed 's/,.*//')' --resolution '$(inrange $resolution $(xPOST res_min) $(xPOST res_max))dpi'$CMD"
	esac
}

imgformat() {
tmp=$(mktemp -u -t tazsane.XXXXXX)
while read key name type exe pkg cmd ; do
	case "$key" in
	\#*)	continue
	esac
	case "$1" in
	list)
		echo -n "<option value=\"$key\""
		[ "$(which $exe 2> /dev/null)" ] || 
		echo -n " disabled title=\"$exe not found: install $pkg\""
		[ "$key" == "pnm" ] &&
		echo -n " title=\"not supported by most browsers\""
		echo ">$key" ;;
	*)
		case "$key" in
		$(xPOST format)|'*')
			case "$HTTP_USER_AGENT" in

			# Tazweb has no download support
			TazWe*)	rm -f /tmp/$name
				eval "$(getgeometry $(xPOST resolution)) $cmd >/tmp/$name" 2> $tmp.err
				if [ -s /tmp/$name ]; then
					info="Stored in /tmp/$name ($(stat -c %s /tmp/$name) bytes)."
				else
					error="$(sed 's|$|<br />|' $tmp.err)"
					[ "$error" ] || error="I/O error"
				fi
				rm -f $tmp.* ;;

			# Others should work
			*)	header	"Content-Type: $type" \
					"Content-Disposition: attachment; filename=$name" \

				eval "$(getgeometry $(xPOST resolution)) $cmd"
				rm -f $tmp.*
				exit ;;
			esac ;;
		esac ;;
	esac
done <<EOT
png		tazsane.png		image/png		convert		imagemagick 	> $tmp.pnm; convert $tmp.pnm png:-
jpeg		tazsane.jpg		image/jpeg		convert		imagemagick 	> $tmp.pnm; convert $tmp.pnm jpg:-
jpeg2000	tazsane.jp2		image/jpeg2000-image	convert		imagemagick 	> $tmp.pnm; convert $tmp.pnm jp2:-
tiff		tazsane.tiff		image/tiff		convert		imagemagick 	> $tmp.pnm; convert $tmp.pnm tiff:-
ps		tazsane.ps		application/postscript	convert		imagemagick 	> $tmp.pnm; convert -page A4+0+0 $tmp.pnm ps:-
pdf		tazsane.pdf		image/pdf		convert		imagemagick 	> $tmp.pnm; convert $tmp.pnm pdf:-
ocr1		tazsane-OCR1.txt	text/plain		gocr		gocr		| gocr -
ocr2		tazsane-OCR2.txt	text/plain		tesseract	tesseract-ocr	| tesseract stdin stdout
pnm		tazsane.pnm		image/pnm		true		slitaz
EOT
}

xPOST() {
	[ "$preview" == "reset" ] || POST $@
}

tmpreview="$(POST tmpreview)"
find tmp/ -name 'tazsane*' -mmin +60 -prune -exec rm -f {} \; 

device="$(POST device)"
preview="$(POST preview)"
info=""
error=""

case " $(POST) " in
*\ reset\ *)
	unset device tmpreview
	preview="reset" ;;
*\ preview\ *)
	[ "$tmpreview" ] || tmpreview=$(mktemp -u -t tazsane.XXXXXX).png
	tmp=$(mktemp -u -t tazsane.XXXXXX)
	eval "$(getgeometry)" > $tmp.pnm 2> $tmp.err
	if [ -s "$tmp.pnm" ]; then
		convert $tmp.pnm $tmpreview > /dev/null 2>&1 ||
		cp $tmp.pnm $tmpreview
	else
		error="$(sed 's|$|<br />|' $tmp.err)"
		rm -f $tmpreview
	fi
	rm -f $tmp.pnm $tmp.err ;;
*\ scan\ *)
	imgformat download ;;
esac

header
xhtml_header
[ -n "$error" ] && msg warn "$error"
[ -n "$info" ] && msg tip "$info"
if [ -z "$device" ]; then
	[ -s sane-fake.log ] && all="$(sed 's/|/\n/g' sane-fake.log)" ||
	all="$(scanimage -f '%d,%v %m|' | sed 's/|/\n/g')"
	case "$(echo "$all" | wc -l)" in
	1)	if [ -z "$all" ]; then
			msg warn 'No scanner found'
			xhtml_footer
			exit 0
		fi
		device="${all%|}" ;;
	*)	cat <<EOT
<section>
	<header>
		<form name="scanner" method="post">
			Scanner
			<select name="device" size=1>
EOT
		echo "$all" | awk -F, '{ if (NF > 0) print "<option value=\"" $0 "\">" 1+i++ " - " $2 }'
		cat <<EOT
			</select>
			<button data-icon="start">$(_ "Continue")</button>
		</form>
	</header>
</section>
EOT
		xhtml_footer
		exit 0 ;;
	esac
fi

cat <<EOT
<section>
<form name="parameters" method="post">
<script language="JavaScript" type="text/javascript">
<!--
function new_width() {
	document.parameters.action = "?width="+document.width
}

window.onresize = new_width
new_width()
-->
</script>

<header>
$(echo $device | sed 's/.*,//')
<div class="float-right">
	<button name="scan" data-icon="start">$(_ "Scan")</button>
	<button name="reset" data-icon="stop">$(_ "Reset")</button>
	<button name="preview" data-icon="view">$(_ "Preview")</button>
</div>
</header>

<table class="wide" border="2" cellpadding="8" cellspacing="0">
<tr>
<td>Format
<select name="format" size=1>
$(imgformat list)
</select>
</td>
EOT

if [ "$(xPOST params)" ]; then
	params="$(xPOST params | uudecode)"
else 
	params="$({
cat "$(echo $device | sed 's/,.*//').log" 2> /dev/null ||
scanimage --help -d "$(echo $device | sed 's/,.*//')"
} | awk '
function minmax()
{
	if (match($2,"[0-9]")) {
		i=$2; sub(/\.\..*/,"",i)
		j=$2; sub(/.*\.\./,"",j)
		sub(/\..*/,"",j); sub(/[dm%].*/,"",j)
		k=$0; sub(/.* \[/,"",k); sub(/\].*/,"",k)
		print $1 " " int(k) " " int(i) " " int(j)
	}
}

function enum()
{
	i=$0
	if (index(i,"|")) {
		sub(/^ *--*[a-z]* */,"",i)
		sub(/dpi .*/,"",i); gsub(/ \[.*\].*/,"",i)
		k=$0; sub(/.* \[/,"",k); sub(/\].*/,"",k)
		gsub(/ /,"=",k)
		print $1 " " k " enum " i
	}
	else minmax()
}

/Options specific to device/ { parse=1 }
{
	if (parse != 1) next
	if (/\[inactive\]/) next
	if (match("-l-t-x-y", $1)) minmax()
	if (match("--resolution--brightness--contrast--source--mode", $1)) enum()
}
')"
fi
output="$(echo "$params" | while read name def min max ; do
	name="${name##*-}"
	def="${def//=/ }"
	if [ "$min" == "enum" ]; then
		res_min=1000000
		res_max=0
		echo "<td>$name"
		echo -n "<select name=\"$name\" size=1"
		[ "$name" == "resolution" ] && echo -n " onchange=showGeometry()"
		echo ">"
		IFS="|"; set -- $max ; unset IFS
		while [ "$1" ]; do
			echo -n "<option value=\"$1\""
			[ "$(xPOST $name)" == "$1" ] && echo -n " selected"
			[ -z "$(xPOST $name)" -a "$def" == "$1" ] && echo -n " selected"
			echo ">$(_ "$1")"
			if [ "$name" == "resolution" ]; then
				[ $res_max -lt $1 ] && res_max=$1
				[ $res_min -gt $1 ] && res_min=$1
			fi
			shift
		done
		echo "</select>"
	else
		[ "$(xPOST $name)" ] && def=$(xPOST $name)
		[ $def -lt $min ] && def=$min
		[ $def -gt $max ] && def=$max
		f="$(_ "$name")<input name=\"$name\" value=\"$def\""
		u=""
		case "$name" in
		x|y|l|t) cat <<EOT
:${name}_max=$max
<input type="hidden" name="${name}_min" value="$min">
<input type="hidden" name="${name}_max" value="$max">
EOT
			while read name2 n2 id val; do
				[ "$name" == "$name2" ] || continue
				[ "$(xPOST geometry_$name)" ] &&
				val="$(xPOST geometry_$name)"
				f="$(_ "$n2")<input name=\"geometry_$name\" id=\"$id\" value=\"$val\""
				u="&nbsp;mm"
				break
			done <<EOT
l	X-Offset	x	0
t	Y-Offset	y	0
x	Width		width	$max
y	Height		height	$max
EOT
			[ "$newline" ] || echo "</tr><tr>"
			newline=$name
		esac
		[ "$name" == "resolution" ] && f="$f onchange=showGeometry()"
		echo "<td>$f type=\"text\" title=\"$min .. $max\" size=4 maxlength=4>$u"
		res_min=$min
		res_max=$max
	fi
	case "$name" in
	resolution) cat <<EOT
<input type="hidden" name="res_min" value="$res_min">
<input type="hidden" name="res_max" value="$res_max">
&nbsp;dpi
EOT
	esac
	echo "</td>"
done)"
echo "$output" | sed '/^:/d'

org_x=$(xPOST geometry_x); [ "$org_x" ] || org_x=$(echo "$output" | sed '/^:x_max=/!d;s/.*=//')
org_y=$(xPOST geometry_y); [ "$org_y" ] || org_y=$(echo "$output" | sed '/^:y_max=/!d;s/.*=//')

cat <<EOT
</tr>
</table>
<input type="hidden" name="tmpreview" value="$tmpreview">
<input type="hidden" name="device" value="$device">
<input type="hidden" name="params" value="$(echo "$params" | uuencode -m -)">
<script language="JavaScript" type="text/javascript">
<!--
function setGeometry(x,y) {
  document.parameters.geometry_x.value = x;
  document.parameters.geometry_y.value = y;
  cropSetFrameByInput();
}

function showGeometry() {
  var resolution = document.parameters.resolution.value;
  if (resolution) {
    resolution /= 25.4;
    var x = Math.floor(document.parameters.geometry_x.value * resolution);
    var y = Math.floor(document.parameters.geometry_y.value * resolution);
    alert((Math.round(x * y / 100000)/10) + ' Mpixels\n' + x + 'x' + y);
  }
}
-->
</script>

<footer align="center">
EOT
awk -vox=$org_x -voy=$org_y 'END {
	x=210*4; y=297*4; n=0; cnt=0;
	while (cnt < 9) {
		if (ox +1 >= x && oy +1 >= y) {
    			print "&nbsp;<a href=\"javascript:setGeometry(" x "," y ")\">DIN-A" n "</a>"
    			cnt++
  		}
		if (ox +1 >= x && oy +1 >= y) {
    			print "&nbsp;<a href=\"javascript:setGeometry(" y "," x ")\">DIN-A" n "L</a>"
    			cnt++
  		}
  		tmp=x; x=y/2; y=tmp
 		n++
}
}' < /dev/null

cat <<EOT
</footer>
</form>
</section>
EOT

[ -s "$tmpreview" ] && cat <<EOT
<div margin="15px" style="overflow-x: auto">
	<script type="text/javascript" src="lib/crop.js"></script>
	<img src="$tmpreview" onload=cropInit(this,'x','y','width','height')>
</div>
EOT
xhtml_footer
