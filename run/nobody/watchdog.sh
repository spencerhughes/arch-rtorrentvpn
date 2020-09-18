#!/bin/bash

# define destination file path for rtorrent config file
rtorrent_config="/config/rtorrent/config/rtorrent.rc"

# if rtorrent config file doesnt exist then copy default to host config volume
if [[ ! -f "${rtorrent_config}" ]]; then

	echo "[info] rTorrent config file doesnt exist, copying default to /config/rtorrent/config/..."

	# copy default rtorrent config file to /config/rtorrent/config/
	mkdir -p /config/rtorrent/config && cp /home/nobody/rtorrent/config/* /config/rtorrent/config/

else

	echo "[info] rTorrent config file already exists, skipping copy"

fi

# replace legacy rtorrent 0.9.6 config entries (rtorrent v0.9.7 does not allow entries below in rtorrent.rc)
sed -i -e 's~use_udp_trackers = yes~trackers.use_udp.set = yes~g' "${rtorrent_config}"
sed -i -e 's~use_udp_trackers = no~trackers.use_udp.set = no~g' "${rtorrent_config}"
sed -i -e 's~peer_exchange = yes~protocol.pex.set = yes~g' "${rtorrent_config}"
sed -i -e 's~peer_exchange = no~protocol.pex.set = no~g' "${rtorrent_config}"

# remove legacy rtorrent 0.9.6 config entries (rtorrent v0.9.7 does not allow entries below in rtorrent.rc)
sed -i '/system.file_allocate.set/d' "${rtorrent_config}"

# force unix line endings conversion in case user edited rtorrent.rc with notepad
/usr/local/bin/dos2unix.sh "${rtorrent_config}"

# create soft link to rtorrent config file
ln -fs "${rtorrent_config}" ~/.rtorrent.rc

# set default values for port and ip
rtorrent_port="49160"
rtorrent_ip="0.0.0.0"

# define sleep period between loops
sleep_period_secs=30

# define sleep period between incoming port checks
sleep_period_incoming_port_secs=1800

# sleep period counter - used to limit number of hits to external website to check incoming port
sleep_period_counter_secs=0

# while loop to check ip and port
while true; do

	# reset triggers to negative values
	rtorrent_running="false"
	privoxy_running="false"
	irssi_running="false"
	ip_change="false"
	rtorrent_port_change="false"

	if [[ "${VPN_ENABLED}" == "yes" ]]; then

		# run script to get all required info
		source /home/nobody/preruncheck.sh

		# if vpn_ip is not blank then run, otherwise log warning
		if [[ ! -z "${vpn_ip}" ]]; then

			# if current bind interface ip is different to tunnel local ip then re-configure rtorrent
			if [[ "${rtorrent_ip}" != "${vpn_ip}" ]]; then

				echo "[info] rTorrent listening interface IP ${rtorrent_ip} and VPN provider IP ${vpn_ip} different, marking for reconfigure"

				# mark as reload required due to mismatch
				ip_change="true"

			fi

			if [[ "${ENABLE_AUTODL_IRSSI}" == "yes" ]]; then

				# if irssi process not running (could be initial start or maybe due to kill rtorrent due to port/ip change) then start irssi
				if ! pgrep -x "irssi" > /dev/null; then

					echo "[info] irssi not running"

				else

					# mark as irssi as running
					irssi_running="true"

				fi

			fi

			# check if rtorrent is running, if not then skip shutdown of process
			if ! pgrep -x "rtorrent main" > /dev/null; then

				echo "[info] rTorrent not running"

			else

				# mark as rtorrent as running
				rtorrent_running="true"

			fi

			if [[ "${ENABLE_PRIVOXY}" == "yes" ]]; then

				# check if privoxy is running, if not then skip shutdown of process
				if ! pgrep -fa "/usr/bin/privoxy" > /dev/null; then

					echo "[info] Privoxy not running"

				else

					# mark as privoxy as running
					privoxy_running="true"

				fi

			fi

			if [[ "${VPN_PROV}" == "pia" ]]; then

				# if vpn port is not an integer then dont change port
				if [[ ! "${VPN_INCOMING_PORT}" =~ ^-?[0-9]+$ ]]; then

					# set vpn port to current rtorrent port, as we currently cannot detect incoming port (line saturated, or issues with pia)
					VPN_INCOMING_PORT="${rtorrent_port}"

					# ignore port change as we cannot detect new port
					rtorrent_port_change="false"

				else

					if [[ "${rtorrent_running}" == "true" ]]; then

						if [ "${sleep_period_counter_secs}" -ge "${sleep_period_incoming_port_secs}" ]; then

							# run script to check incoming port is accessible
							source /home/nobody/checkextport.sh

							# reset sleep period counter
							sleep_period_counter_secs=0

						fi

					fi

					if [[ "${rtorrent_port}" != "${VPN_INCOMING_PORT}" ]]; then

						echo "[info] rTorrent incoming port $rtorrent_port and VPN incoming port ${VPN_INCOMING_PORT} different, marking for reconfigure"

						# mark as reconfigure required due to mismatch
						rtorrent_port_change="true"

					fi

				fi

			fi

			if [[ "${ENABLE_AUTODL_IRSSI}" == "yes" ]]; then

				if [[ "${irssi_running}" == "false" ]]; then

					# run script to start irssi
					source /home/nobody/irssi.sh

				fi

			fi

			if [[ "${rtorrent_port_change}" == "true" || "${ip_change}" == "true" || "${rtorrent_running}" == "false" ]]; then

				# run script to start rtorrent, it can also perform shutdown of rtorrent if its already running (required for port/ip change)
				source /home/nobody/rtorrent.sh

				# if the exit code is non 0 (bad vpn_ip due to remote server change?) then skip initplugins.sh as this will block
				if [[ "${?}" -ne 0 ]]; then

					echo "[warn] Failed to start rTorrent, skipping initialisation of ruTorrent Plugins..."

				else

					# run script to initialise rutorrent plugins
					source /home/nobody/initplugins.sh

				fi


			fi

			if [[ "${ENABLE_PRIVOXY}" == "yes" ]]; then

				if [[ "${privoxy_running}" == "false" ]]; then

					# run script to start privoxy
					source /home/nobody/privoxy.sh

				fi

			fi

		else

			echo "[warn] VPN IP not detected, VPN tunnel maybe down"

		fi

	else

		if [[ "${ENABLE_AUTODL_IRSSI}" == "yes" ]]; then

			# if irssi process not running (could be initial start or maybe due to kill rtorrent due to port/ip change) then start irssi
			if ! pgrep -x "irssi" > /dev/null; then

				echo "[info] irssi not running"

				# run script to start autodl-irssi
				source /home/nobody/irssi.sh

			fi

		fi

		# check if rtorrent is running, if not then start via rtorrent.sh
		if ! pgrep -x "rtorrent main" > /dev/null; then

			echo "[info] rTorrent not running"

			# run script to start rtorrent
			source /home/nobody/rtorrent.sh

			# if the exit code is non 0 (bad vpn_ip due to remote server change?) then skip initplugins.sh as this will block
			if [[ "${?}" -ne 0 ]]; then

				echo "[warn] Failed to start rTorrent, skipping initialisation of ruTorrent Plugins..."

			else

				# run script to initialise rutorrent plugins
				source /home/nobody/initplugins.sh

			fi

		fi

		if [[ "${ENABLE_PRIVOXY}" == "yes" ]]; then

			# check if privoxy is running, if not then start via privoxy.sh
			if ! pgrep -fa "/usr/bin/privoxy" > /dev/null; then

				echo "[info] Privoxy not running"

				# run script to start privoxy
				source /home/nobody/privoxy.sh

			fi

		fi

	fi

	if [[ "${DEBUG}" == "true" && "${VPN_ENABLED}" == "yes" ]]; then

		if [[ "${VPN_PROV}" == "pia" && -n "${VPN_INCOMING_PORT}" ]]; then

			echo "[debug] VPN incoming port is ${VPN_INCOMING_PORT}"
			echo "[debug] rTorrent incoming port is ${rtorrent_port}"

		fi

		echo "[debug] VPN IP is ${vpn_ip}"
		echo "[debug] rTorrent IP is ${rtorrent_ip}"

	fi

	# increment sleep period counter - used to limit number of hits to external website to check incoming port
	sleep_period_counter_secs=$((sleep_period_counter_secs+"${sleep_period_secs}"))

	sleep "${sleep_period_secs}"s

done
