export EDITOR=nvim
export VISUAL=nvim
alias vi=nvim
alias vim=nvim

alias l="ls --color=auto --group-directories-first"
alias ll="ls -lh --color=auto --group-directories-first"
alias la="ls -A --color=auto --group-directories-first"
alias lla="ls -lhA --color=auto --group-directories-first"
alias ls="ls --color=auto --group-directories-first"

# Debian packages bat's binary as "batcat"; AlmaLinux/EPEL ships it as "bat".
if command -v batcat >/dev/null 2>&1; then
  alias cat="batcat -pP"
elif command -v bat >/dev/null 2>&1; then
  alias cat="bat -pP"
fi
