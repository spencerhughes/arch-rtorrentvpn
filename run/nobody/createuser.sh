#!/bin/bash

if [ -z "${1}" ]; then
	echo "[crit] Missing username parameter, exiting script..."
	exit 1
fi

if [ -z "${2}" ]; then
	echo "[crit] Missing password parameter, exiting script..."
	exit 1
fi

# path to nginx auth file
webui_auth="/config/nginx/security/webui_auth"

# if nginx auth file doesnt exist then create, else append credentials
if [[ -f "${webui_auth}" ]]; then
  /usr/bin/htpasswd -b "${webui_auth}" "${1}" "${2}"
else
  /usr/bin/htpasswd -b -c "${webui_auth}" "${1}" "${2}"
fi

status=$?
if [[ $status -eq 0 ]]; then
  echo "User account '${1}' created with password '${2}'"
else
  echo "Failed to create user account '${1}'"
fi
