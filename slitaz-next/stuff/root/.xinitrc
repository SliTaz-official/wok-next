# ~/.xinitrc: Executed by Slim/LXDM login manager to startx X session.
# You can use F1 with Slim to change your window manager or configure
# it permanently with your personal applications.conf file.
#
. $HOME/.config/slitaz/applications.conf
tazbox mkmenu

[ "$1" ] && WINDOW_MANAGER="$1"

EXEC="exec ck-launch-session dbus-launch --sh-syntax --exit-with-session"

LOG="/tmp/log" ; X=$LOG ; ERR=$X

case "$WINDOW_MANAGER" in
	openbox|lxde*|icewm*|xfce4|compiz|karmen|dwm|fluxbox*|razor*|mate*)
		$EXEC ${WINDOW_MANAGER%-session}-session ;;
	enlightenment)
		$EXEC enlightenment_start ;;
	kde)	$EXEC startkde ;;
	lxqt)	$EXEC startlxqt ;;
	*)	$EXEC $WINDOW_MANAGER ;;
esac	2>>$ERR >>$X
