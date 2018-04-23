#!/bin/bash

# if autodl-irssi enabled then run, else log
if [[ "${ENABLE_AUTODL_IRSSI}" == "yes" ]]; then

	# run script to check ip is valid for tunnel device (will block until valid)
	if [[ "${VPN_ENABLED}" == "yes" ]]; then
		source /home/nobody/getvpnip.sh
	fi

	# change directory to script location and then run irssi via tmux
	cd /home/nobody/.irssi/scripts/autorun

	# create tmux session name 'irssi_session' and window name 'irssi_window'
	# note the window number starts at 0
	/usr/bin/script /home/nobody/typescript --command "/usr/bin/tmux new-session -d -s irssi_session -n irssi_window /usr/bin/irssi"

	# send command to update trackers using tmux send-keys command sent to
	# the session name and window number (0 in this case)
	tmux send-keys -t irssi_session:0 "/autodl update" ENTER

else

	echo "[info] Autodl-irssi not enabled, skipping startup"

fi
