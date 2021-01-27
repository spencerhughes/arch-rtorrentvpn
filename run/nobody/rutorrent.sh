#!/bin/bash

# function to enable/disable authentication for rpc2 and webui (/)
function nginx_auth {

ENABLE_AUTH="${1}"
auth_file="${2}"
location="${3}"

if [[ "${location}" == "/RPC2" ]]; then

    if [[ "${ENABLE_AUTH}" == "yes" ]]; then

            # inserts location (basic auth) into existing nginx.conf
            sed -i "s~location ${location} {~location ${location} {\\
            include scgi_params;\\
            scgi_pass 127.0.0.1:5000;\\
            auth_basic \"Restricted Content\";\\
            auth_basic_user_file ${auth_file};~g" '/config/nginx/config/nginx.conf'

    else

            # inserts location (no auth) into existing nginx.conf
            sed -i "s~location ${location} {~location ${location} {\\
            include scgi_params;\\
            scgi_pass 127.0.0.1:5000;~g" '/config/nginx/config/nginx.conf'

    fi

else

    if [[ "${ENABLE_AUTH}" == "yes" ]]; then

            # inserts location (basic auth) into existing nginx.conf
            sed -i "s~location ${location} {~location ${location} {\\
            index index.html index.htm index.php;\\
            auth_basic \"Restricted Content\";\\
            auth_basic_user_file ${auth_file};~g" '/config/nginx/config/nginx.conf'

    else

            # inserts location (no auth) into existing nginx.conf
            sed -i "s~location ${location} {~location ${location} {\\
            index index.html index.htm index.php;~g" '/config/nginx/config/nginx.conf'

    fi

fi

}

# function to configure php paths to external apps for existing users - delme 20200417
function configure_php {

# remove external applications section from users config.php
sed -i '/$pathToExternals = array(/,/);/{//!d}' "/config/rutorrent/conf/config.php"

# defines paths to external applications in users config.php
sed -i 's~$pathToExternals = array(.*~$pathToExternals = array(\
                "php"           => \x27/usr/bin/php\x27,              // Something like /usr/bin/php. If empty, will be found in PATH.\
                "curl"          => \x27/usr/bin/curl\x27,             // Something like /usr/bin/curl. If empty, will be found in PATH.\
                "gzip"          => \x27/usr/bin/gzip\x27,             // Something like /usr/bin/gzip. If empty, will be found in PATH.\
                "id"            => \x27/usr/bin/id\x27,               // Something like /usr/bin/id. If empty, will be found in PATH.\
                "python"        => \x27/usr/bin/python\x27,           // Something like /usr/bin/python. If empty, will be found in PATH.\
                "pgrep"         => \x27/usr/bin/pgrep\x27,            // Something like /usr/bin/pgrep. If empty, will be found in PATH.\
                "sox"           => \x27/usr/bin/sox\x27,              // Something like /usr/bin/sox. If empty, will be found in PATH.\
                "stat"          => \x27/usr/bin/stat\x27,             // Something like /usr/bin/stat. If empty, will be found in PATH.~g' "/config/rutorrent/conf/config.php"
}

# wait for rtorrent process to start (listen for port)
while [[ $(netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".5000"') == "" ]]; do
	sleep 0.1
done

echo "[info] rtorrent started, setting up rutorrent..."

# if nginx cert files dont exist then copy defaults to host config volume (location specified in nginx.conf, no need to soft link)
if [[ ! -f "/config/nginx/certs/host.cert" || ! -f "/config/nginx/certs/host.key" ]]; then

	echo "[info] nginx cert files doesnt exist, copying default to /config/nginx/certs/..."

	mkdir -p '/config/nginx/certs'
	cp '/home/nobody/nginx/certs/'* '/config/nginx/certs/'

else

	echo "[info] nginx cert files already exists, skipping copy"

fi

# if nginx config file doesnt exist then copy default to host config volume (soft linked)
if [ ! -f "/config/nginx/config/nginx.conf" ]; then

	echo "[info] nginx config file doesnt exist, copying default to /config/nginx/config/..."

	mkdir -p '/config/nginx/config'

	# if nginx defaiult config file exists then delete
	if [[ -f "/etc/nginx/nginx.conf" && ! -L "/etc/nginx/nginx.conf" ]]; then
		rm -rf '/etc/nginx/nginx.conf'
	fi
	
	cp '/home/nobody/nginx/config/'* '/config/nginx/config/'

else

	echo "[info] nginx config file already exists, skipping copy"

fi

# create soft link to nginx config file
ln -fs '/config/nginx/config/nginx.conf' '/etc/nginx/nginx.conf'

# if php.ini file exists in container then rename
if [[ -f "/etc/php/php.ini" && ! -L "/etc/php/php.ini" ]]; then
	mv '/etc/php/php.ini' '/etc/php/php.ini-backup' 2>/dev/null || true
fi

# if php.ini file doesnt exist then copy default to host config volume (soft linked)
if [ ! -f "/config/rutorrent/php/php.ini" ]; then

	echo "[info] php.ini file doesnt exist, copying default to /config/rutorrent/php/..."

	mkdir -p '/config/rutorrent/php'
	cp '/etc/php/php.ini-backup' '/config/rutorrent/php/php.ini'

else

	echo "[info] php.ini file already exists, skipping copy"

fi

# create soft link to php.ini file
ln -fs '/config/rutorrent/php/php.ini' '/etc/php/php.ini'

# if conf folder exists in container then rename
if [[ -d "/usr/share/webapps/rutorrent/conf" && ! -L "/usr/share/webapps/rutorrent/conf" ]]; then
	mv '/usr/share/webapps/rutorrent/conf' '/usr/share/webapps/rutorrent/conf-backup' 2>/dev/null || true
fi

# if rutorrent conf folder doesnt exist then copy default to host config volume (soft linked)
if [ ! -d "/config/rutorrent/conf" ]; then

	echo "[info] rutorrent conf folder doesnt exist, copying default to /config/rutorrent/conf/..."

	mkdir -p '/config/rutorrent/conf'
	if [[ -d "/usr/share/webapps/rutorrent/conf-backup" && ! -L "/usr/share/webapps/rutorrent/conf-backup" ]]; then
		cp -R '/usr/share/webapps/rutorrent/conf-backup/'* '/config/rutorrent/conf/' 2>/dev/null || true
	fi

else

	echo "[info] rutorrent conf folder already exists, skipping copy"

	if ! (grep 'python' "/config/rutorrent/conf/config.php"); then
		echo "[info] php configuration missing external application paths, configuring..."
		configure_php
	fi

fi

# create soft link to rutorrent conf folder
ln -fs '/config/rutorrent/conf' '/usr/share/webapps/rutorrent'

# copy plugins.ini from container to host volume map required for users
# with existing plugins.ini, new users will not need this, please remove
cp -f '/usr/share/webapps/rutorrent/conf-backup/plugins.ini' '/config/rutorrent/conf/plugins.ini'

# if autodl-irssi enabled then enable plugin
if [[ "${ENABLE_AUTODL_IRSSI}" == "yes" ]]; then

	# enable autodl-plugin
	sed -i -r '/^\[autodl-irssi\]/!b;n;cenabled = yes' '/config/rutorrent/conf/plugins.ini'

else

	# disable autodl-plugin
	sed -i -r '/^\[autodl-irssi\]/!b;n;cenabled = no' '/config/rutorrent/conf/plugins.ini'

fi

# if php timezone specified then set in php.ini (prevents issues with dst and rutorrent scheduler plugin)
if [[ ! -z "${PHP_TZ}" ]]; then

	echo "[info] Setting PHP timezone to ${PHP_TZ}..."
	sed -i -e "s~.*date\.timezone \=.*~date\.timezone \= ${PHP_TZ}~g" "/config/rutorrent/php/php.ini"

else

	echo "[warn] PHP timezone not set, this may cause issues with the ruTorrent Scheduler plugin, see here for a list of available PHP timezones, http://php.net/manual/en/timezones.php"

fi

# create folder for rutorrent user plugins
mkdir -p '/config/rutorrent/user-plugins/theme/themes'
echo "Please place additional ruTorrent Plugins in this folder, and then restart the container for the change to take affect" > /config/rutorrent/user-plugins/README.txt
echo "Please place additional ruTorrent Themes in this folder, and then restart the container for the change to take affect" > /config/rutorrent/user-plugins/theme/themes/README.txt
echo "[info] running rsync to copy rutorrent user plugins to the plugins folder inside the container..."
rsync --quiet --recursive --compress --update '/config/rutorrent/user-plugins/' '/usr/share/webapps/rutorrent/plugins/'

# if share folder exists in container then rename
if [[ -d "/usr/share/webapps/rutorrent/share" && ! -L "/usr/share/webapps/rutorrent/share" ]]; then
	mv '/usr/share/webapps/rutorrent/share' '/usr/share/webapps/rutorrent/share-backup' 2>/dev/null || true
fi

# if rutorrent share folder doesnt exist then copy default to host config volume (soft linked)
if [ ! -d "/config/rutorrent/share" ]; then

	echo "[info] rutorrent share folder doesnt exist, copying default to /config/rutorrent/share/..."

	mkdir -p '/config/rutorrent/share'
	if [[ -d "/usr/share/webapps/rutorrent/share-backup" && ! -L "/usr/share/webapps/rutorrent/share-backup" ]]; then
		cp -R '/usr/share/webapps/rutorrent/share-backup/'* '/config/rutorrent/share/' 2>/dev/null || true
	fi

else

	echo "[info] rutorrent share folder already exists, skipping copy"

fi

# create soft link to rutorrent share folder
ln -fs '/config/rutorrent/share' '/usr/share/webapps/rutorrent'

# if defunct plugins-backup folder exists in container then rename back to plugins (for existing users)
# this change is due to corruption of plugins and updates to plugins causing incompatibility
if [ -d "/usr/share/webapps/rutorrent/plugins-backup" ]; then
	rm -rf '/usr/share/webapps/rutorrent/plugins' 2>/dev/null || true
	mv '/usr/share/webapps/rutorrent/plugins-backup' '/usr/share/webapps/rutorrent/plugins' 2>/dev/null || true
fi

# if defunct plugins host volume map folder exists then remove (for existing users)
# this change is due to corruption of plugins and updates to plugins causing incompatibility
if [ -d "/config/rutorrent/plugins" ]; then
	rm -rf '/config/rutorrent/plugins' 2>/dev/null || true
fi

# if rpc enabled then proceed, else delete
if [[ "${ENABLE_RPC2}" == "yes" ]]; then

	echo "[info] nginx /rpc2 location enabled"

	auth_file="/config/nginx/security/rpc2_auth"

	# check if rpc2 is secure
	check_rpc2_secure=$(awk '/location \/RPC2 {/,/\}/' /config/nginx/config/nginx.conf | xargs -0 | grep -ioP "auth_basic_user_file ${auth_file};")

	# if rpc authentication enabled then add in lines
	if [[ "${ENABLE_RPC2_AUTH}" == "yes" ]]; then

		mkdir -p '/config/nginx/security'

		if [[ -z "${check_rpc2_secure}" ]]; then

			echo "[info] enabling basic auth for /rpc2..."

			# delete existing /rpc2 location (cannot easily edit and replace lines without insertion)
			sed -i -r '/location \/RPC2\s/,/}/{//!d}' "/config/nginx/config/nginx.conf"

			# call function to enable authentication for rpc2
			nginx_auth "${ENABLE_RPC2_AUTH}" "${auth_file}" "/RPC2"

		fi

		if [ -f "${auth_file}" ]; then

			echo "[info] Updating password for rpc2 account '${RPC2_USER}'..."
			/usr/bin/htpasswd -b "${auth_file}" "${RPC2_USER}" "${RPC2_PASS}"

		else

			echo "[info] Creating auth file for rpc2 account '${RPC2_USER}'..."
			/usr/bin/htpasswd -b -c "${auth_file}" "${RPC2_USER}" "${RPC2_PASS}"

		fi

	else

		echo "[info] disabling basic auth for /rpc2..."

		# delete existing /rpc2 location (cannot easily edit and replace lines without insertion)
		sed -i -r '/location \/RPC2\s/,/}/{//!d}' "/config/nginx/config/nginx.conf"

		# call function to disable authentication for rpc2
		nginx_auth "${ENABLE_RPC2_AUTH}" "" "/RPC2"

	fi

else

	echo "[info] nginx /rpc2 location not enabled"

	# delete existing /rpc2 location
	sed -i -r '/location \/RPC2\s/,/}/{//!d}' "/config/nginx/config/nginx.conf"

fi

# if web ui authentication enabled then add in lines
if [[ "${ENABLE_WEBUI_AUTH}" == "yes" ]]; then

	mkdir -p '/config/nginx/security'

	auth_file="/config/nginx/security/webui_auth"

	# check web ui (/) is secure
	check_webui_secure=$(awk '/location \/ {/,/\}/' /config/nginx/config/nginx.conf | xargs -0 | grep -ioP "auth_basic_user_file ${auth_file};")

	if [[ -z "${check_webui_secure}" ]]; then

		echo "[info] enabling basic auth for web ui..."

		# delete existing / location (cannot easily edit and replace lines without insertion)
		sed -i -r '/location \/\s/,/}/{//!d}' "/config/nginx/config/nginx.conf"

		# call function to enable authentication for web ui
		nginx_auth "${ENABLE_WEBUI_AUTH}" "${auth_file}" "/"

	fi

	if [ -f "${auth_file}" ]; then

		echo "[info] Updating password for web ui account '${WEBUI_USER}'..."
		/usr/bin/htpasswd -b "${auth_file}" "${WEBUI_USER}" "${WEBUI_PASS}"

	else

		echo "[info] Creating auth file for web ui account '${WEBUI_USER}'..."
		/usr/bin/htpasswd -b -c "${auth_file}" "${WEBUI_USER}" "${WEBUI_PASS}"

	fi

else

	echo "[info] disabling basic auth for web ui..."

	# delete existing web ui location (/) (cannot easily edit and replace lines without insertion)
	sed -i -r '/location \/\s/,/}/{//!d}' "/config/nginx/config/nginx.conf"

	# call function to disable authentication for web ui
	nginx_auth "${ENABLE_WEBUI_AUTH}" "" "/"

fi

echo "[info] starting php-fpm..."

# run php-fpm and specify path to pid file
/usr/bin/php-fpm --pid '/home/nobody/php-fpm.pid'

echo "[info] starting nginx..."

# hard link (soft link doesn't fix the issue) the nginx binary to prevent Apparmor trigger for
# Synology users - link to issue:- https://github.com/binhex/arch-rtorrentvpn/issues/138
#
# run nginx in foreground and specify path to pid file
ln -f '/usr/bin/nginx' '/home/nobody/bin/'
/home/nobody/bin/nginx -g "daemon off; pid /home/nobody/nginx.pid;"
