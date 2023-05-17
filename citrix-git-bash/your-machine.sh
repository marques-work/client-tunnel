#!/bin/bash
# vim: sts=2 sw=2 et

set -euo pipefail

declare -r BASTION='54.200.185.166'

function main {
  local action=''
  declare -a all_args=()

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
  # opens port 2200 on your machine and forwards traffic to port 2222
  # on the bastion's loopback interface.
  #
  # if you've set up the tunnel on the target machine, then traffic
  # to port 2222 on the bastion's loopback interface should reach the
  # target machine's SSH port.
  #
  # of course, you can then add more tunnels using the target machine
  # once you've opened one to its SSH port :). even a SOCKS5 proxy!
  ssh \
    -o 'StrictHostKeyChecking=no' \
    -o 'UserKnownHostsFile=/dev/null' \
    ec2-user@$BASTION -fNT -L 2200:127.0.0.1:2222

  info "The tunnel should be up."
}

function conn_down {
  local candidates=''

  # shellcheck disable=SC2009
  if ! candidates="$(ps -eo pid,command | grep -vF grep | grep -F "ec2-user@$BASTION -fNT -L 2200:127.0.0.1:2222")"; then
    info "The tunnel doesn't appear to be up"
    return 0
  fi

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
