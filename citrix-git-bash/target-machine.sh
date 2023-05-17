#!/bin/bash
# vim: sts=2 sw=2 et

set -euo pipefail

# Install this file in your PATH on the machine you want to
# reach behind the firewall. Call it tun.sh or something short.
# This script is written, expecting to be on an MSYS environment,
# like git-bash on Windows.
#
# It requires OpenSSH, which should be installed. It also requires
# that you've set up /usr/bin/sshd on that box, which you can run
# unprivileged if you specify your own sshd_config, host keys, and
# a high port number. This script assumes you've started it on port
# 2200 bound to at least loopback, if not all interfaces.
#
# Naturally, it also assumes you've set up SSH keys to the bastion
# and target host, or you're willing to use passwords.
#
# USAGE: tun.sh --up
# USAGE: tun.sh --down

# You might be able to do without a bastion if you open a port
# on your router at home. I generally don't like to do that,
# even though there might be less latency. I'd rather not have
# a network trail to my public IP.
#
# I recommend only using SSH keys that are encrypted with
# passwords. Just use `ssh-agent` if it's annoying to type each
# time, but that means there's no tunneling back from the remote
# machine unless someone with your key knows YOUR password.
#
# Modify this to your jumphost
declare -r BASTION='54.200.185.166'

function main {
  local action=''
  declare -a all_args

  for arg in "$@"; do
    case "$arg" in
      --up|--down)
        action="$arg"
        ;;
      -*)
        die "don't know what to do with flag: '$arg'"
        ;;
      *)
        all_args+=("$arg")
        ;;
    esac
  done

  if [ -z "$action" ]; then
    die "you need to specify either the --up or --down flag"
  fi

  set -- ${all_args[@]+"${all_args[@]}"}

  if [ "--up" = "$action" ]; then
    conn_up
  else
    conn_down
  fi
}

function conn_up {
  # opens port 2222 on the BASTION's loopback interface and
  # forwards traffic back here to port 2200
  ssh \
    -o 'StrictHostKeyChecking=no' \
    -o 'UserKnownHostsFile=/dev/null' \
    ec2-user@$BASTION -fNT -R 2222:127.0.0.1:2200

  info "The tunnel should be up."
}

function conn_down {
  # `ps` in MSYS is almost useless here. The COMMAND column never shows
  # arguments, only the program -- even with `-f` or `-l`; it doesn't
  # support `-o` at all.

  local candidates=''

  if ! candidates="$(ps -ef | awk '{$1=$3=$4=$5=""; print $0}' | grep '/usr/bin/ssh$')"; then
    info "The tunnel doesn't appear to be up"
    return 0
  fi

  # Unfortunately, this crude heuristic is the best way to kill the tunnel.
  #
  # Yes, kill all ssh sessions.
  #
  # We can't used `ps` to get the exact pid by matching args. We also can't
  # use the subshell `exec` + `echo $$` trick because `ssh -f` spawns a child
  # process anyway and daemonizes it with a new PID under PPID 1, so no PIDFILE
  # either. We're caught between a rock and a hard place here, so we take the
  # nuclear approach. Oh, well.
  info "Killing these processes"
  printf '%s\n' "$candidates"

  printf '%s' "$candidates" | awk '{print $1}' | xargs kill -KILL
  info "Done."
}

function info {
  >&2 printf '\e[32;1m[INFO ] %s\e[0m\n' "$*"
}

function die {
  >&2 printf '\e[31;1m[FATAL] %s\e[0m\n' "$*"
  exit 1
}

main "$@"
