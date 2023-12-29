#!/bin/bash
##### -*- mode:shell-script; indent-tabs-mode:nil; sh-basic-offset:2 -*-
##### Author: Travis Cross <tc@traviscross.com>

browser="Chromium|Chrome|Iceweasel|Firefox"
tab_title=""
ht_path=""
do_chown=false
owner=""
do_chmod=false
perms=""

usage() {
  echo "usage: $0 [-b <browser title>] [-o <owner[:group]>] [-p <perm mode>] [-t <tab title>] <path>">&2
  exit 1
}

while getopts 'b:dho:p:t:' o "$@"; do
  case "$o" in
    b) browser="$OPTARG";;
    d) set -vx;;
    h) usage;;
    o) do_chown=true; owner="$OPTARG";;
    p) do_chmod=true; perms="$OPTARG";;
    t) tab_title="$OPTARG";;
  esac
done
shift $(($OPTIND-1))

if [ "$#" -lt 1 ]; then usage; fi
ht_path="$1"

if $do_chown; then chown -R "$owner" $ht_path; fi
if $do_chmod; then chmod -R "$perms" $ht_path; fi

last=$(date +%s)
inotifywait -m -r \
  --exclude '/\.git/|/\.#|/#' \
  --format '%e %w%f' \
  -e 'modify,moved_to,moved_from,move,create,delete' \
  "$ht_path" \
  | while read -r ev fl; do
  echo "$ev $fl" >&2
  now=$(date +%s)
  if [ "$ev" != "DELETE" ]; then
    $do_chown && chown "$owner" "$fl"
    $do_chmod && chmod "$perms" "$fl"
  fi
  if test $((now > last+1)) -eq 1; then
    last=$now
    br () {
      sleep 0.1; # 0.1 seconds
      xdotool search --onlyvisible --name "${tab_title}.*(${browser})$" $@;
    }
    if [ -n "$(br)" ]; then
      echo "refreshing...">&2
      br key --clearmodifiers --window %@ 'F5'
      xs=$(br | while read x; do
            printf "%s" " windowfocus $x key --clearmodifiers F5"; done)
      xs="$xs windowfocus $(xdotool getactivewindow)"
      xdotool $xs
    fi
  fi
done
