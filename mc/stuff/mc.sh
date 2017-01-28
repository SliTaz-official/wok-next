#!/bin/sh

case $TERM in
	linux*)
		{
		cat <<EOT
shift   keycode  59 = F11
shift   keycode  60 = F12
shift   keycode  61 = F13
shift   keycode  62 = F14
shift   keycode  63 = F15
shift   keycode  64 = F16
shift   keycode  65 = F17
shift   keycode  66 = F18
shift   keycode  67 = F19
shift   keycode  68 = F20
EOT
		} | loadkeys -uv
		sleep 1
		;;
	xterm*)
		export TERM='xterm-color'
		[ -f '/usr/share/terminfo/s/screen-256color' ] &&
			export TERM='screen-256color'
		;;
esac
mc $@
