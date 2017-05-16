#!/bin/bash

# if flood enabled then log
if [[ "${ENABLE_FLOOD}" == "yes" ]]; then

	echo "[info] Flood enabled, preventing ruTorrent Web UI from starting..."

else

	# wait for rtorrent process to start (listen for port)
	while [[ $(netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".5000"') == "" ]]; do
		sleep 0.1
	done

	echo "[info] rtorrent started, setting up rutorrent..."

	# if php timezone specified then set in php.ini (prevents issues with dst and rutorrent scheduler plugin)
	if [[ ! -z "${PHP_TZ}" ]]; then

		echo "[info] Setting PHP timezone to ${PHP_TZ}..."
		sed -i -e "s~.*date\.timezone \=.*~date\.timezone \= ${PHP_TZ}~g" "/etc/php/php.ini"

	else

		echo "[warn] PHP timezone not set, this may cause issues with the ruTorrent Scheduler plugin, see here for a list of available PHP timezones, http://php.net/manual/en/timezones.php"

	fi

	# if nginx cert files dont exist then copy defaults to host config volume (location specified in nginx.conf, no need to soft link)
	if [[ ! -f "/config/nginx/certs/host.cert" || ! -f "/config/nginx/certs/host.key" ]]; then

		echo "[info] nginx cert files doesnt exist, copying default to /config/nginx/certs/..."

		mkdir -p /config/nginx/certs
		cp /home/nobody/nginx/certs/* /config/nginx/certs/

	else

		echo "[info] nginx cert files already exists, skipping copy"

	fi

	# if nginx security file doesnt exist then copy default to host config volume (location specified in nginx.conf, no need to soft link)
	if [ ! -f "/config/nginx/security/auth" ]; then

		echo "[info] nginx security file doesnt exist, copying default to /config/nginx/security/..."

		mkdir -p /config/nginx/security
		cp /home/nobody/nginx/security/* /config/nginx/security/

	else

		echo "[info] nginx security file already exists, skipping copy"

	fi

	# if nginx config file doesnt exist then copy default to host config volume (soft linked)
	if [ ! -f "/config/nginx/config/nginx.conf" ]; then

		echo "[info] nginx config file doesnt exist, copying default to /config/nginx/config/..."

		mkdir -p /config/nginx/config

		# if nginx defaiult config file exists then delete
		if [[ -f "/etc/nginx/nginx.conf" && ! -L "/etc/nginx/nginx.conf" ]]; then
			rm -rf /etc/nginx/nginx.conf
		fi
		
		cp /home/nobody/nginx/config/* /config/nginx/config/

	else

		echo "[info] nginx config file already exists, skipping copy"

	fi

	# create soft link to nginx config file
	ln -fs /config/nginx/config/nginx.conf /etc/nginx/nginx.conf

	# if conf folder exists in container then rename
	if [[ -d "/etc/webapps/rutorrent/conf" && ! -L "/etc/webapps/rutorrent/conf" ]]; then
		mv /etc/webapps/rutorrent/conf /etc/webapps/rutorrent/conf-backup 2>/dev/null || true
	fi

	# if rutorrent conf folder doesnt exist then copy default to host config volume (soft linked)
	if [ ! -d "/config/rutorrent/conf" ]; then

		echo "[info] rutorrent conf folder doesnt exist, copying default to /config/rutorrent/conf/..."

		mkdir -p /config/rutorrent/conf
		if [[ -d "/etc/webapps/rutorrent/conf-backup" && ! -L "/etc/webapps/rutorrent/conf-backup" ]]; then
			cp -R /etc/webapps/rutorrent/conf-backup/* /config/rutorrent/conf/ 2>/dev/null || true
		fi

	else

		echo "[info] rutorrent conf folder already exists, skipping copy"

	fi

	# create soft link to rutorrent conf folder
	ln -fs /config/rutorrent/conf /etc/webapps/rutorrent

	# if share folder exists in container then rename
	if [[ -d "/usr/share/webapps/rutorrent/share" && ! -L "/usr/share/webapps/rutorrent/share" ]]; then
		mv /usr/share/webapps/rutorrent/share /usr/share/webapps/rutorrent/share-backup 2>/dev/null || true
	fi

	# if rutorrent share folder doesnt exist then copy default to host config volume (soft linked)
	if [ ! -d "/config/rutorrent/share" ]; then

		echo "[info] rutorrent share folder doesnt exist, copying default to /config/rutorrent/share/..."

		mkdir -p /config/rutorrent/share
		if [[ -d "/usr/share/webapps/rutorrent/share-backup" && ! -L "/usr/share/webapps/rutorrent/share-backup" ]]; then
			cp -R /usr/share/webapps/rutorrent/share-backup/* /config/rutorrent/share/ 2>/dev/null || true
		fi

	else

		echo "[info] rutorrent share folder already exists, skipping copy"

	fi

	# create soft link to rutorrent share folder
	ln -fs /config/rutorrent/share /usr/share/webapps/rutorrent

	# if plugins folder exists in container then rename
	if [ -d "/usr/share/webapps/rutorrent/plugins" ]; then
		mv /usr/share/webapps/rutorrent/plugins /usr/share/webapps/rutorrent/plugins-backup 2>/dev/null || true
	fi

	# if plugins folder doesnt exist on /config then copy default set from container
	if [ ! -d "/config/rutorrent/plugins" ]; then
		echo "[info] rutorrent plugins folder doesnt exist, copying plugins from container..."
		mkdir -p /config/rutorrent/plugins
		rsync -a /usr/share/webapps/rutorrent/plugins-backup/ /config/rutorrent/plugins/ 2>/dev/null || true
	fi

	# rsync plugins from /config to container to capture user installed plugins and/or deletions (cannot soft link thus copy back)
	echo "[info] copying rutorrent plugins to container..."
	mkdir -p /usr/share/webapps/rutorrent/plugins
	rsync --delete -a /config/rutorrent/plugins/ /usr/share/webapps/rutorrent/plugins/ 2>/dev/null || true

	echo "[info] starting php-fpm..."

	# run php-fpm and specify path to pid file
	/usr/bin/php-fpm --pid /home/nobody/php-fpm.pid

	echo "[info] starting nginx..."

	# run nginx in foreground and specify path to pid file
	/usr/bin/nginx -g "daemon off; pid /home/nobody/nginx.pid;"

fi
