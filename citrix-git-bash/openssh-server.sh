#!/bin/bash
# vim: sts=2 sw=2 et

set -euo pipefail

readonly HOST_KEY_DIR="$HOME/.ssh/host-keys"
readonly CONFIG_DIR="$HOME/.ssh/server"
readonly HOST_KEY="$HOST_KEY_DIR/ssh_host_ed25519_key"
readonly SSHD_CONFIG="$CONFIG_DIR/sshd_config"
readonly SSHD_CONFIG_DEFAULT="/etc/ssh/sshd_config"

function main {
  if [ ! -f /usr/bin/ssh ]; then
    die "OpenSSH is missing! It's supposed to come with \`git-bash\`!"
  fi

  if [ "$#" -ne 1 ]; then
    die "USAGE: $(basename "$0") start|restart|stop"
  fi

  local action=''

  case "$1" in
    start|restart)
      action="start"
      ;;
    stop)
      action="stop"
      ;;
    *)
      die "USAGE: $(basename "$0") start|restart|stop"
      ;;
  esac

  ensure_host_keys
  ensure_sshd_config

  if [ "start" = "$action" ]; then
    stop
    start
  else
    stop
  fi
}

function start {
  info "Starting sshd"
  # in git-bash, you MUST use the full sshd path, even if it's on your PATH
  /usr/bin/sshd -f "$SSHD_CONFIG"

  info "Done."
}

function stop {
  local pidfile="$CONFIG_DIR/ssh.pid"

  if [ -f "$pidfile" ]; then
    info "Killing pid in $pidfile"
    kill -TERM "$(cat "$pidfile")"
  fi

  # shellcheck disable=SC2155
  local orphaned="$(ps -ef | awk '{$1=$3=$4=$5=""; print $0}' | grep '/usr/bin/sshd$')"

  if [ -n "$orphaned" ]; then
    info "Killing orphaned sshd processes:"
    printf '%s\n' "$orphaned"
    printf '%s' "$orphaned" | awk '{print $1}' | xargs kill -KILL
    info "Done."
  else
    info "No orphaned sshd processes to kill; done."
  fi
}

function ensure_sshd_config {
  info "Updating $SSHD_CONFIG"

  mkdir -p "$CONFIG_DIR"
  sed \
    -e 's,^#Port 22$,Port 2200,g' \
    -e 's,^#ListenAddress 0\.0\.0\.0$,ListenAddress 127.0.0.1,g' \
    -e "s,^#HostKey /etc/ssh/ssh_host_ed25519_key,HostKey $HOST_KEY,g" \
    -e 's,^#AllowAgentForwarding yes$,AllowAgentForwarding yes,g' \
    -e 's,^#AllowTcpForwarding yes$,AllowTcpForwarding yes,g' \
    -e 's,^#X11Forwarding no$,X11Forwarding yes,g' \
    -e "s,^#PidFile /etc/ssh/sshd.pid,PidFile $CONFIG_DIR/sshd.pid,g" \
    "$SSHD_CONFIG_DEFAULT" > "$SSHD_CONFIG"
}

function ensure_host_keys {
  if [ ! -f "$HOST_KEY" ]; then
    info "Generating host keys for this machine"
    mkdir -p "$(dirname "$HOST_KEY")"
    ssh-keygen -N '' -t ed25519 -a 40 -f "$HOST_KEY"
  else
    info "Found host keys at: $HOST_KEY"
  fi
}

function info {
  >&2 printf '\e[32;1m[INFO ] %s\e[0m\n' "$*"
}

function die {
  >&2 printf '\e[31;1m[FATAL] %s\e[0m\n' "$*"
  exit 1
}

main "$@"
