#!/bin/sh
#
# Openbox pipe menu to launch rox-filer using GTK bookmarks.
#

cat <<EOT
<openbox_pipe_menu>
	<item label="Home">
		<action name="Execute">
			<execute>rox-filer ~</execute>
		</action>
	</item>
EOT


# GTK bookmarks
for dir in $(sed 's/[ ][^ ]*$//' .gtk-bookmarks | sed 's!file://!!'); do
	label=$(basename $dir)
	cat <<EOT
	<item label="$label">
		<action name="Execute">
			<execute>rox-filer $dir</execute>
		</action>
	</item>
EOT
done

echo '</openbox_pipe_menu>'
