#!/bin/bash

# if autodl-irssi enabled then run, else log
if [[ "${ENABLE_AUTODL_IRSSI}" == "yes" ]]; then

	mkdir -p /config/autodl

	if [ ! -f /config/autodl/autodl.cfg ]; then
		cp /home/nobody/.autodl/autodl.cfg.bak /config/autodl/autodl.cfg
	fi

	ln -fs /config/autodl/autodl.cfg /home/nobody/.autodl/autodl.cfg

	# change directory to script location and then run irssi via tmux
	cd /home/nobody/.irssi/scripts/autorun

	echo "[info] Attempting to start irssi..."

	# create tmux session name 'irssi_session' and window name 'irssi_window'
	# note the window number starts at 0
	/usr/bin/script /home/nobody/typescript --command "/usr/bin/tmux new-session -d -s irssi_session -n irssi_window /usr/bin/irssi"

	echo "[info] irssi process started, updating trackers..."

	# send command to update trackers using tmux send-keys command sent to
	# the session name and window number (0 in this case)
	tmux send-keys -t irssi_session:0 "/autodl update" ENTER

	echo "[info] irssi trackers updated"

else

	echo "[info] Autodl-irssi not enabled, skipping startup"

fi
