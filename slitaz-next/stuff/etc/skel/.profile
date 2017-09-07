# ~/.profile: Executed by Bourne-compatible login SHells.
#

. /etc/profile
. /etc/locale.conf

# Path to personal scripts and executables (~/.local/bin).
#
if [ -d "$HOME/.local/bin" ] ; then
	PATH=$HOME/.local/bin:$PATH
	export PATH
fi

# fix menu prefix
export XDG_MENU_PREFIX='lxde-'

export XDG_CACHE_HOME=$HOME/.cache
export XDG_DATA_HOME=$HOME/.local/share
export XDG_CONFIG_HOME=$HOME/.config

# Environnement variables and prompt for Ash SHell
# or Bash. Default is a classic prompt.
#
#PS1='\u@\h:\w\$ '
# colored prompt
PS1='\[\e[0;32m\]\u@\h\[\e[0m\]:\[\e[0;33m\]\w\[\e[0m\]\$ '


EDITOR='nano'
PAGER='less -EM'

export PS1 EDITOR PAGER

# Alias definitions.
#
alias df='df -h'
alias du='du -h'

alias ls='ls -p'
alias ll='ls -l'
alias la='ls -la'

# Avoid errors... use -f to skip confirmation.
alias rm='rm -i'
alias mv='mv -i'

umask 022
