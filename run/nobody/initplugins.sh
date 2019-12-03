#!/bin/bash

echo "[info] Initialising ruTorrent plugins (checking rTorrent is running)..."

# wait for rtorrent process to start (listen for port)
while [[ $(netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".5000"') == "" ]]; do
	sleep 0.1
done

echo "[info] rTorrent running"
echo "[info] Initialising ruTorrent plugins (checking nginx is running)..."

# wait for nginx process to start (listen for port)
while [[ $(netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".9080"') == "" ]]; do
	sleep 0.1
done

echo "[info] nginx running"
echo "[info] Initialising ruTorrent plugins..."

# run php plugins for rutorent (required for scheduler and rss feed plugins)
/usr/bin/php /usr/share/webapps/rutorrent/php/initplugins.php "${WEBUI_USER}"
echo "[info] ruTorrent plugins initialised"
