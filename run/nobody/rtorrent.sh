#!/bin/bash

# if rtorrent is already running then use xmlrpc to reconfigure
if [[ "${rtorrent_running}" == "true" ]]; then

	# useful for debug and finding valid methods
	#rtxmlrpc system.listMethods
	# note '' is required? as first parameter for subsequent rtxmlrpc commands

	if [[ "${VPN_PROV}" == "pia" && -n "${VPN_INCOMING_PORT}" ]]; then

		# set new value for incoming port
		if rtxmlrpc network.port_range.set '' "${VPN_INCOMING_PORT}-${VPN_INCOMING_PORT}"; then
			# set rtorrent port to current vpn port (used when checking for changes on next run)
			rtorrent_port="${VPN_INCOMING_PORT}"
		fi

		# set new value for dht port (same as incoming port)
		rtxmlrpc dht.port.set '' "${VPN_INCOMING_PORT}"

	fi

	# bind address will fail if incoming port is not defined, thus we check the port is set
	if [[ $(rtxmlrpc network.port_range) ]]; then

		# set new value for bind to vpn tunnel ip
		if rtxmlrpc network.bind_address.set '' "${vpn_ip}"; then
			# set rtorrent ip to current vpn ip (used when checking for changes on next run)
			rtorrent_ip="${vpn_ip}"
		fi

		# set new value for ip address sent to tracker
		rtxmlrpc network.local_address.set '' "${external_ip}"

	else

		echo "[warn] Incoming port range not defined, unable to bind IP address"

	fi

else

	echo "[info] Removing any rTorrent session lock files left over from the previous run..."
	rm -f /config/rtorrent/session/*.lock

	echo "[info] Attempting to start rTorrent..."

	if [[ "${VPN_ENABLED}" == "yes" ]]; then

		if [[ "${VPN_PROV}" == "pia" && -n "${VPN_INCOMING_PORT}" ]]; then

			# run tmux attached to rTorrent (daemonized, non-blocking), specifying listening interface and incoming and dht port
			/usr/bin/script /home/nobody/typescript --command "/usr/bin/tmux new-session -d -s rt -n rtorrent /usr/bin/rtorrent -b ${vpn_ip} -p ${VPN_INCOMING_PORT}-${VPN_INCOMING_PORT} -o ip=${external_ip} -o dht_port=${VPN_INCOMING_PORT}"

			# set rtorrent port to current vpn port (used when checking for changes on next run)
			rtorrent_port="${VPN_INCOMING_PORT}"

		else

			# run tmux attached to rTorrent (daemonized, non-blocking), specifying listening interface
			/usr/bin/script /home/nobody/typescript --command "/usr/bin/tmux new-session -d -s rt -n rtorrent /usr/bin/rtorrent -b ${vpn_ip} -o ip=${external_ip}"

		fi

	else

		# run tmux attached to rTorrent (daemonized, non-blocking)
		/usr/bin/script /home/nobody/typescript --command "/usr/bin/tmux new-session -d -s rt -n rtorrent /usr/bin/rtorrent"

	fi

	# make sure process rtorrent DOES exist
	retry_count=12
	retry_wait=1
	while true; do

		if ! pgrep -x "rtorrent main" > /dev/null; then

			retry_count=$((retry_count-1))
			if [ "${retry_count}" -eq "0" ]; then

				echo "[warn] Wait for rTorrent process to start aborted, too many retries" ; return 1

			else

				if [[ "${DEBUG}" == "true" ]]; then
					echo "[debug] Waiting for rTorrent process to start"
					echo "[debug] Re-check in ${retry_wait} secs..."
					echo "[debug] ${retry_count} retries left"
				fi
				sleep "${retry_wait}s"

			fi

		else

			echo "[info] rTorrent process started"
			break

		fi

	done

	echo "[info] Waiting for rTorrent process to start listening on port 5000..."

	while [[ $(netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".5000"') == "" ]]; do
		sleep 0.1
	done

	echo "[info] rTorrent process listening on port 5000"

	# set rtorrent ip to current vpn ip (used when checking for changes on next run)
	rtorrent_ip="${vpn_ip}"

fi
