#!/bin/bash

if [ -z "${1}" ]; then
	echo "[crit] Missing username parameter, exiting script..."
	exit 1
fi

# path to nginx auth file
webui_auth="/config/nginx/security/webui_auth"

# delete existing user account for nginx
/usr/bin/htpasswd -D "${webui_auth}" "$1"

status=$?

if [[ $status -eq 0 ]]; then
  echo "User account $1 deleted."
else
  echo "Failed to delete user account $1, does it exist?"
fi
