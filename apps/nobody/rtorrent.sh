#!/bin/bash

# if rtorrent config file doesnt exist then copy default to host config volume
if [[ ! -f "/config/rtorrent/config/rtorrent.rc" ]]; then

	echo "[info] rTorrent config file doesnt exist, copying default to /config/rtorrent/config/..."

	# copy default rtorrent config file to /config/rtorrent/config/
	mkdir -p /config/rtorrent/config && cp /home/nobody/rtorrent/config/* /config/rtorrent/config/

else

	echo "[info] rTorrent config file already exists, skipping copy"

fi

# create soft link to rtorrent config file
ln -fs /config/rtorrent/config/rtorrent.rc ~/.rtorrent.rc

# if vpn set to "no" then don't run openvpn
if [[ "${VPN_ENABLED}" == "no" ]]; then

	echo "[info] VPN not enabled, skipping VPN tunnel local ip/port checks"

	rtorrent_ip="0.0.0.0"

	echo "[info] Removing any rtorrent session lock files left over from the previous run..."
	rm -f /config/rtorrent/session/*.lock

	# run rTorrent (non daemonized, blocking)
	echo "[info] Attempting to start rTorrent..."
	/usr/bin/script /home/nobody/typescript --command "/usr/bin/tmux new-session -s rt -n rtorrent /usr/bin/rtorrent -b ${rtorrent_ip} -o ip=${rtorrent_ip}" &>/dev/null

else

	echo "[info] VPN is enabled, checking VPN tunnel local ip is valid"

	# define connection to rtorrent rpc (used to reconfigure rtorrent)
	xmlrpc_connection="localhost:9080"

	# set triggers to first run
	rtorrent_running="false"
	ip_change="false"
	port_change="false"

	# set default values for port and ip
	rtorrent_port="49160"
	rtorrent_ip="0.0.0.0"

	# while loop to check ip and port
	while true; do

		# run script to check ip is valid for tunnel device (will block until valid)
		source /home/nobody/getvpnip.sh

		# if vpn_ip is not blank then run, otherwise log warning
		if [[ ! -z "${vpn_ip}" ]]; then

			# check if rtorrent is running, if not then skip reconfigure for port/ip
			if ! pgrep -x rtorrent > /dev/null; then

				echo "[info] rTorrent not running"

				# mark as rtorrent not running
				rtorrent_running="false"

			else

				# if rtorrent is running, then reconfigure port/ip
				rtorrent_running="true"

			fi

			# if current bind interface ip is different to tunnel local ip then re-configure rtorrent
			if [[ "${rtorrent_ip}" != "${vpn_ip}" ]]; then

				echo "[info] rTorrent listening interface IP $rtorrent_ip and VPN provider IP ${vpn_ip} different, marking for reconfigure"

				# mark as reload required due to mismatch
				ip_change="true"

			fi

			if [[ "${VPN_PROV}" == "pia" ]]; then

				# run scripts to identify vpn port
				source /home/nobody/getvpnport.sh

				# if vpn port is not an integer then dont change port
				if [[ ! "${VPN_INCOMING_PORT}" =~ ^-?[0-9]+$ ]]; then

					# set vpn port to current rtorrent port, as we currently cannot detect incoming port (line saturated, or issues with pia)
					VPN_INCOMING_PORT="${rtorrent_port}"

					# ignore port change as we cannot detect new port
					port_change="false"

				else

					if [[ "${rtorrent_running}" == "true" ]]; then

						# run netcat to identify if port still open, use exit code
						nc_exitcode=$(/usr/bin/nc -z -w 3 "${rtorrent_ip}" "${rtorrent_port}")

						if [[ "${nc_exitcode}" -ne 0 ]]; then

							echo "[info] rTorrent incoming port closed, marking for reconfigure"

							# mark as reconfigure required due to mismatch
							port_change="true"

						elif [[ "${rtorrent_port}" != "${VPN_INCOMING_PORT}" ]]; then

							echo "[info] rTorrent incoming port $rtorrent_port and VPN incoming port ${VPN_INCOMING_PORT} different, marking for reconfigure"

							# mark as reconfigure required due to mismatch
							port_change="true"

						fi

					fi

				fi

			fi

			if [[ "${rtorrent_running}" == "true" ]]; then

				if [[ "${VPN_PROV}" == "pia" ]]; then

					# reconfigure rtorrent with new port
					if [[ "${port_change}" == "true" ]]; then

						echo "[info] Reconfiguring rTorrent due to port change..."
						xmlrpc "${xmlrpc_connection}" set_port_range "${VPN_INCOMING_PORT}-${VPN_INCOMING_PORT}" &>/dev/null
						xmlrpc "${xmlrpc_connection}" set_dht_port "${VPN_INCOMING_PORT}" &>/dev/null
						echo "[info] rTorrent reconfigured for port change"

					fi
				fi

				# reconfigure rtorrent with new ip
				if [[ "${ip_change}" == "true" ]]; then

					echo "[info] Reconfiguring rTorrent due to ip change..."
					xmlrpc "${xmlrpc_connection}" set_bind "${vpn_ip}" &>/dev/null
					xmlrpc "${xmlrpc_connection}" set_ip "${external_ip}" &>/dev/null
					echo "[info] rTorrent reconfigured for ip change"

				fi

				# pause/resume "started" torrents after port/ip change (required to reconnect)
				if [[ "${port_change}" == "true" || "${ip_change}" == "true" ]]; then

					# get space seperated list of torrents with status "started"
					torrent_hash_string=$(xmlrpc localhost:9080 download_list "i/0" "started" | grep -P -o "\'[a-zA-Z0-9]+\'" | xargs)
					echo "[info] List of torrent hashes to pause/resume is ${torrent_hash_string}"

					# if torrent_hash_string is not empty then pause/resume running torrents
					if [[ ! -z "${torrent_hash_string}" ]]; then

						echo "[info] Pausing and resuming started torrents due to port/ip change..."

						# convert space seperated string to array
						read -ra torrent_hash_array <<< "${torrent_hash_string}"

						# loop over list of torrent hashes and pause/resume
						for torrent_hash_item in "${torrent_hash_array[@]}"; do

							if [[ "${DEBUG}" == "true" ]]; then
								echo "[debug] Pausing/resuming torrent hash ${torrent_hash_item}"
							fi

							xmlrpc "${xmlrpc_connection}" d.pause "${torrent_hash_item}" &>/dev/null
							xmlrpc "${xmlrpc_connection}" d.resume "${torrent_hash_item}" &>/dev/null

						done

					else

						echo "[info] No torrents with status of started found, skipping pause/resume cycle"

					fi

				fi

			else

				echo "[info] Attempting to start rTorrent..."

				echo "[info] Removing any rtorrent session lock files left over from the previous run..."
				rm -f /config/rtorrent/session/*.lock

				if [[ "${VPN_PROV}" == "pia" || -n "${VPN_INCOMING_PORT}" ]]; then

					# run tmux attached to rTorrent (daemonized, non-blocking), specifying listening interface and port
					/usr/bin/script /home/nobody/typescript --command "/usr/bin/tmux new-session -d -s rt -n rtorrent /usr/bin/rtorrent -b ${vpn_ip} -p ${VPN_INCOMING_PORT}-${VPN_INCOMING_PORT} -o ip=${external_ip} -o dht_port=${VPN_INCOMING_PORT}"

				else

					# run tmux attached to rTorrent (daemonized, non-blocking), specifying listening interface
					/usr/bin/script /home/nobody/typescript --command "/usr/bin/tmux new-session -d -s rt -n rtorrent /usr/bin/rtorrent -b ${vpn_ip} -o ip=${external_ip}"

				fi

				echo "[info] rTorrent started"
				
				# run script to initialise rutorrent plugins
				source /home/nobody/initplugins.sh

			fi

			# set rtorrent ip and port to current vpn ip and port (used when checking for changes on next run)
			rtorrent_ip="${vpn_ip}"
			rtorrent_port="${VPN_INCOMING_PORT}"

			# reset triggers to negative values
			rtorrent_running="false"
			ip_change="false"
			port_change="false"

			if [[ "${DEBUG}" == "true" ]]; then

				echo "[debug] VPN incoming port is ${VPN_INCOMING_PORT}"
				echo "[debug] VPN IP is ${vpn_ip}"
				echo "[debug] rTorrent incoming port is ${rtorrent_port}"
				echo "[debug] rTorrent IP is ${rtorrent_ip}"

			fi

		else

			echo "[warn] VPN IP not detected, VPN tunnel maybe down"

		fi

		sleep 30s

	done

fi
