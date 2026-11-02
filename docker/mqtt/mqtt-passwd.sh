#!/usr/bin/env bash
# Manage Mosquitto users. Put it next to compose.yml.
#   ./mqtt-passwd.sh add <user>       asks for the password
#   ./mqtt-passwd.sh add <user> -g    generates a random one and prints it
#   ./mqtt-passwd.sh del <user>
#   ./mqtt-passwd.sh list
# Runs mosquitto_passwd inside the container, so the file ends up owned by
# the container user (compose.yml "user:"). Restart mqtt afterwards.
set -euo pipefail
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
cd "$(dirname "$SELF")"

SERVICE=mqtt
HOST_FILE=config/passwd
CONT_FILE=/mosquitto/config/passwd

usage() {
  sed -n '2,6p' "$SELF" | sed 's/^# \{0,1\}//' >&2
  exit 1
}

passwd_cmd() {
  docker compose run --rm --no-deps --entrypoint mosquitto_passwd "$SERVICE" "$@"
}

[ "$#" -ge 1 ] || usage
action="$1"

case "$action" in
  add)
    [ "$#" -ge 2 ] || usage
    user="$2"
    create=()
    [ -f "$HOST_FILE" ] || create=(-c)   # -c would wipe an existing file
    if [ "${3:-}" = "-g" ]; then
      pass="$(openssl rand -base64 24)"
      passwd_cmd -b ${create[@]+"${create[@]}"} "$CONT_FILE" "$user" "$pass"
      echo "user: $user"
      echo "password: $pass"
    else
      passwd_cmd ${create[@]+"${create[@]}"} "$CONT_FILE" "$user"
    fi
    chmod 600 "$HOST_FILE"
    echo "Done. Restart to apply: docker compose restart $SERVICE"
    ;;
  del)
    [ "$#" -eq 2 ] || usage
    passwd_cmd -D "$CONT_FILE" "$2"
    echo "Done. Restart to apply: docker compose restart $SERVICE"
    ;;
  list)
    [ -f "$HOST_FILE" ] || { echo "no $HOST_FILE yet" >&2; exit 1; }
    cut -d: -f1 "$HOST_FILE"
    ;;
  *)
    usage
    ;;
esac
