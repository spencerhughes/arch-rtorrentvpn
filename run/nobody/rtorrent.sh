#!/bin/bash

# kill rtorrent (required due to the fact rtorrent cannot cope with dynamic changes to port)
if [[ "${rtorrent_running}" == "true" ]]; then

	if [[ "${ENABLE_RPC2_AUTH}" == "yes" ]]; then
		xmlrpc_connection="localhost:9080 -username=${RPC2_USER} -password=${RPC2_PASS}"
	else
		xmlrpc_connection="localhost:9080"
	fi

	# useful for debug and finding valid methods
	#xmlrpc ${xmlrpc_connection} system.listMethods

	# note 'i/0' is required? (integer) as first parameter for subsequent xmlrpc commands

	# set new value for incoming port
	if xmlrpc ${xmlrpc_connection} network.port_range.set 'i/0' "${VPN_INCOMING_PORT}-${VPN_INCOMING_PORT}"; then
		# set rtorrent port to current vpn port (used when checking for changes on next run)
		rtorrent_port="${VPN_INCOMING_PORT}"
	fi

	# set new value for bind to vpn tunnel ip
	# note this must come AFTER the port has been changed, otherwise the port change does not take effect
	if xmlrpc ${xmlrpc_connection} network.bind_address.set 'i/0' "${vpn_ip}"; then
		# set rtorrent ip to current vpn ip (used when checking for changes on next run)
		rtorrent_ip="${vpn_ip}"
	fi

	# set new value for ip address sent to tracker
	xmlrpc ${xmlrpc_connection} network.local_address.set 'i/0' "${external_ip}"

	# set new value for dht port (same as incoming port)
	xmlrpc ${xmlrpc_connection} dht.port.set 'i/0' "${VPN_INCOMING_PORT}"

else

	echo "[info] Removing any rTorrent session lock files left over from the previous run..."
	rm -f /config/rtorrent/session/*.lock

	echo "[info] Attempting to start rTorrent..."

	if [[ "${VPN_ENABLED}" == "yes" ]]; then

		if [[ "${VPN_PROV}" == "pia" && -n "${VPN_INCOMING_PORT}" ]]; then

			# run tmux attached to rTorrent (daemonized, non-blocking), specifying listening interface and port
			/usr/bin/script /home/nobody/typescript --command "/usr/bin/tmux new-session -d -s rt -n rtorrent /usr/bin/rtorrent -b ${vpn_ip} -p ${VPN_INCOMING_PORT}-${VPN_INCOMING_PORT} -o ip=${external_ip} -o dht_port=${VPN_INCOMING_PORT}"

		else

			# run tmux attached to rTorrent (daemonized, non-blocking), specifying listening interface
			/usr/bin/script /home/nobody/typescript --command "/usr/bin/tmux new-session -d -s rt -n rtorrent /usr/bin/rtorrent -b ${vpn_ip} -o ip=${external_ip}"

		fi

	else

		# run tmux attached to rTorrent (daemonized, non-blocking)
		/usr/bin/script /home/nobody/typescript --command "/usr/bin/tmux new-session -d -s rt -n rtorrent /usr/bin/rtorrent"

	fi

	# make sure process rtorrent DOES exist
	retry_count=30
	while true; do

		if ! pgrep -x "rtorrent main" > /dev/null; then

			retry_count=$((retry_count-1))
			if [ "${retry_count}" -eq "0" ]; then

				echo "[warn] Wait for rTorrent process to start aborted, too many retries" ; return 1

			else

				if [[ "${DEBUG}" == "true" ]]; then
					echo "[debug] Waiting for rTorrent process to start..."
				fi

				sleep 1s

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

fi

# set rtorrent port to current vpn port (used when checking for changes on next run)
rtorrent_port="${VPN_INCOMING_PORT}"

# set rtorrent ip to current vpn ip (used when checking for changes on next run)
rtorrent_ip="${vpn_ip}"
