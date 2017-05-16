#!/bin/bash

# if flood enabled then run, else log
if [[ "${ENABLE_FLOOD}" == "yes" || "${ENABLE_FLOOD}" == "both" ]]; then

	echo "[info] Flood enabled, waiting for rTorrent to start..."

	# wait for rtorrent process to start (listen for port)
	while [[ $(netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".5000"') == "" ]]; do
		sleep 0.1
	done

	echo "[info] rTorrent started, configuring Flood..."

	flood_config_path="/config/flood/config"
	flood_install_path="/etc/webapps/flood"

	# if flood config file doesnt exist then copy default to host config volume
	# note flood does not support softlink of config file, thus we need to
	# copy from /config/flood back to the container.
	if [ ! -f "${flood_config_path}/config.js" ]; then

		echo "[info] Flood config file doesnt exist in /config/flood/, copying from container..."
		mkdir -p "${flood_config_path}/"
		cp -f "${flood_install_path}/config-backup.js" "${flood_config_path}/config.js"

	else

		echo "[info] Flood config file already exists in /config/flood/, copying back to container..."
		cp -f "${flood_config_path}/config.js" "${flood_install_path}/config.js"

	fi

	echo "[info] Starting Flood..."

	# run tmux attached to flood (non daemonized, blocking)
	cd "${flood_install_path}" && /usr/bin/script /home/nobody/typescript --command "/usr/bin/tmux new-session -s flood -n flood npm run start:production" &>/dev/null

else

	echo "[info] Flood not enabled, skipping starting Flood Web UI"

fi
