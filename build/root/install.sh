#!/bin/bash

# exit script if return code != 0
set -e

# build scripts
####

# download build scripts from github
curly.sh -rc 6 -rw 10 -of /tmp/scripts-master.zip -url https://github.com/binhex/scripts/archive/master.zip

# unzip build scripts
unzip /tmp/scripts-master.zip -d /tmp

# move shell scripts to /root
mv /tmp/scripts-master/shell/arch/docker/*.sh /root/

# temp hack until base is rebuilt - move curly to /usr/local/bin to overwrite older ver
mv /root/curly.sh /usr/local/bin/

# pacman packages
####

# define pacman packages
pacman_packages="git nginx php-fpm rsync openssl tmux gnu-netcat mediainfo npm nodejs php-geoip ipcalc"

# install compiled packages using pacman
if [[ ! -z "${pacman_packages}" ]]; then
	pacman -S --needed $pacman_packages --noconfirm
fi

# aor packages
####

# define arch official repo (aor) packages
aor_packages="rtorrent"

# call aor script (arch official repo)
source /root/aor.sh

# aur packages
####

# define aur packages
aur_packages="rutorrent"

# call aur install script (arch user repo)
source /root/aur.sh

# call custom install script
source /root/custom.sh

# config - php
####

# configure php memory limit to improve performance
sed -i -e "s~.*memory_limit\s\=\s.*~memory_limit = 512M~g" "/etc/php/php.ini"

# configure php max execution time to try and prevent timeout issues
sed -i -e "s~.*max_execution_time\s\=\s.*~max_execution_time = 300~g" "/etc/php/php.ini"

# configure php max file uploads to prevent issues with reaching limit of upload count
sed -i -e "s~.*max_file_uploads\s\=\s.*~max_file_uploads = 200~g" "/etc/php/php.ini"

# configure php max input variables (get/post/cookies) to prevent warnings issued
sed -i -e "s~.*max_input_vars\s\=\s.*~max_input_vars = 10000~g" "/etc/php/php.ini"

# configure php upload max filesize to prevent large torrent files failing to upload
sed -i -e "s~.*upload_max_filesize\s\=\s.*~upload_max_filesize = 20M~g" "/etc/php/php.ini"

# configure php post max size (linked to upload max filesize)
sed -i -e "s~.*post_max_size\s\=\s.*~post_max_size = 25M~g" "/etc/php/php.ini"

# configure php with additional php-geoip module
sed -i -e "/.*extension=gd.so/a extension=geoip.so" "/etc/php/php.ini"

# configure php-fpm to use tcp/ip connection for listener
echo "" >> /etc/php/php-fpm.conf
echo "; Set php-fpm to use tcp/ip connection" >> /etc/php/php-fpm.conf
echo "listen = 127.0.0.1:7777" >> /etc/php/php-fpm.conf

# configure php-fpm listener for user nobody, group users
echo "" >> /etc/php/php-fpm.conf
echo "; Specify user listener owner" >> /etc/php/php-fpm.conf
echo "listen.owner = nobody" >> /etc/php/php-fpm.conf
echo "" >> /etc/php/php-fpm.conf
echo "; Specify user listener group" >> /etc/php/php-fpm.conf
echo "listen.group = users" >> /etc/php/php-fpm.conf

# config - rutorrent
####

# set path to curl as rutorrent doesnt seem to find it on the path statement
sed -i -e "s~\"curl\"[[:space:]]\+\=>[[:space:]]\+'',~\"curl\"   \=> \'/usr/bin/curl\'\,~g" "/etc/webapps/rutorrent/conf/config.php"

# set the rutorrent autotools/autowatch plugin to 30 secs scan time, default is 300 secs
sed -i -e "s~\$autowatch_interval \= 300\;~\$autowatch_interval \= 30\;~g" "/usr/share/webapps/rutorrent/plugins/autotools/conf.php"

# set the rutorrent schedulder plugin to 10 mins, default is 60 mins
sed -i -e "s~\$updateInterval \= 60\;~\$updateInterval \= 10\;~g" "/usr/share/webapps/rutorrent/plugins/scheduler/conf.php"

# set the rutorrent diskspace plugin to point at the /data volume mapping, default is /
sed -i -e "s~\$partitionDirectory \= \&\$topDirectory\;~\$partitionDirectory \= \"/data\";~g" "/usr/share/webapps/rutorrent/plugins/diskspace/conf.php"

# delete rutorrent tracklabels plugin (causes error messages and crashes rtorrent) and screenshots plugin (not required on headless system)
rm -rf "/usr/share/webapps/rutorrent/plugins/tracklabels" "/usr/share/webapps/rutorrent/plugins/screenshots"

# config - flood
####

# copy config template file
cp /etc/webapps/flood/config.template.js /etc/webapps/flood/config-backup.js

# modify template with connection details to rtorrent
sed -i "s~host:.*~host: '127.0.0.1',~g" /etc/webapps/flood/config-backup.js

# point key and cert at nginx (note ssl not enabled by default)
sed -i "s~sslKey:.*~sslKey: '/config/nginx/certs/host.key',~g" /etc/webapps/flood/config-backup.js
sed -i "s~sslCert:.*~sslCert: '/config/nginx/certs/host.cert',~g" /etc/webapps/flood/config-backup.js

# set location of database (stores settings and user accounts)
sed -i "s~dbPath:.*~dbPath: '/config/flood/db/',~g" /etc/webapps/flood/config-backup.js

# set ip of host (talk on all ip's)
sed -i "s~floodServerHost.*~floodServerHost: '0.0.0.0',~g" /etc/webapps/flood/config-backup.js

# container perms
####

# create file with contets of here doc
 cat <<'EOF' > /tmp/permissions_heredoc
# set permissions inside container
chown -R "${PUID}":"${PGID}" /etc/webapps/ /usr/share/webapps/ /usr/share/nginx/html/ /etc/nginx/ /etc/php/ /run/php-fpm/ /var/lib/nginx/ /var/log/nginx/ /etc/privoxy/ /home/nobody/ /etc/webapps/flood
chmod -R 775 /etc/webapps/ /usr/share/webapps/ /usr/share/nginx/html/ /etc/nginx/ /etc/php/ /run/php-fpm/ /var/lib/nginx/ /var/log/nginx/ /etc/privoxy/ /home/nobody/ /etc/webapps/flood

# set shell for user nobody
chsh -s /bin/bash nobody

EOF

# replace permissions placeholder string with contents of file (here doc)
sed -i '/# PERMISSIONS_PLACEHOLDER/{
    s/# PERMISSIONS_PLACEHOLDER//g
    r /tmp/permissions_heredoc
}' /root/init.sh
rm /tmp/permissions_heredoc

# env vars
####

cat <<'EOF' > /tmp/envvars_heredoc

# check for presence of network interface docker0
check_network=$(ifconfig | grep docker0 || true)

# if network interface docker0 is present then we are running in host mode and thus must exit
if [[ ! -z "${check_network}" ]]; then
	echo "[crit] Network type detected as 'Host', this will cause major issues, please stop the container and switch back to 'Bridge' mode" | ts '%Y-%m-%d %H:%M:%.S' && exit 1
fi

export VPN_ENABLED=$(echo "${VPN_ENABLED}" | sed -e 's/^[ \t]*//')
if [[ ! -z "${VPN_ENABLED}" ]]; then
	echo "[info] VPN_ENABLED defined as '${VPN_ENABLED}'" | ts '%Y-%m-%d %H:%M:%.S'
else
	echo "[warn] VPN_ENABLED not defined,(via -e VPN_ENABLED), defaulting to 'yes'" | ts '%Y-%m-%d %H:%M:%.S'
	export VPN_ENABLED="yes"
fi

if [[ $VPN_ENABLED == "yes" ]]; then

	# create directory to store openvpn config files
	mkdir -p /config/openvpn

	# set perms and owner for files in /config/openvpn directory
	set +e
	chown -R "${PUID}":"${PGID}" "/config/openvpn" &> /dev/null
	exit_code_chown=$?
	chmod -R 775 "/config/openvpn" &> /dev/null
	exit_code_chmod=$?
	set -e

	if (( ${exit_code_chown} != 0 || ${exit_code_chmod} != 0 )); then
		echo "[warn] Unable to chown/chmod /config/openvpn/, assuming SMB mountpoint" | ts '%Y-%m-%d %H:%M:%.S'
	fi

	# wildcard search for openvpn config files (match on first result)
	export VPN_CONFIG=$(find /config/openvpn -maxdepth 1 -name "*.ovpn" -print -quit)

	# if ovpn file not found in /config/openvpn and the provider is not pia then exit
	if [[ -z "${VPN_CONFIG}" ]]; then
		echo "[crit] Missing OpenVPN configuration file in /config/openvpn/ (no files with an ovpn extension exist), please create and then restart this container, exiting..." | ts '%Y-%m-%d %H:%M:%.S' && exit 1
	fi

	echo "[info] VPN config file (ovpn extension) is located at ${VPN_CONFIG}" | ts '%Y-%m-%d %H:%M:%.S'

	# convert CRLF (windows) to LF (unix) for ovpn
	/usr/bin/dos2unix "${VPN_CONFIG}" 1> /dev/null

	# parse values from ovpn file
	export vpn_remote_line=$(cat "${VPN_CONFIG}" | grep -Po '(?<=^remote\s)[^\n\r]+')
	if [[ ! -z "${vpn_remote_line}" ]]; then
		echo "[info] VPN remote line defined as '${vpn_remote_line}'" | ts '%Y-%m-%d %H:%M:%.S'
	else
		echo "[crit] VPN configuration file ${VPN_CONFIG} does not contain 'remote' line, showing contents of file before exit..." | ts '%Y-%m-%d %H:%M:%.S'
		cat "${VPN_CONFIG}" && exit 1
	fi

	export VPN_REMOTE=$(echo "${vpn_remote_line}" | grep -Po '^[^\s\r\n]+')
	if [[ ! -z "${VPN_REMOTE}" ]]; then
		echo "[info] VPN_REMOTE defined as '${VPN_REMOTE}'" | ts '%Y-%m-%d %H:%M:%.S'
	else
		echo "[crit] VPN_REMOTE not found in ${VPN_CONFIG}, exiting..." | ts '%Y-%m-%d %H:%M:%.S' && exit 1
	fi

	export VPN_PORT=$(echo "${vpn_remote_line}" | grep -Po '[\d]{2,5}+$')
	if [[ ! -z "${VPN_PORT}" ]]; then
		echo "[info] VPN_PORT defined as '${VPN_PORT}'" | ts '%Y-%m-%d %H:%M:%.S'
	else
		echo "[crit] VPN_PORT not found in ${VPN_CONFIG}, exiting..." | ts '%Y-%m-%d %H:%M:%.S' && exit 1
	fi

	export VPN_PROTOCOL=$(cat "${VPN_CONFIG}" | grep -Po '(?<=^proto\s)[^\r\n]+')
	if [[ ! -z "${VPN_PROTOCOL}" ]]; then
		echo "[info] VPN_PROTOCOL defined as '${VPN_PROTOCOL}'" | ts '%Y-%m-%d %H:%M:%.S'
		# required for use in iptables
		if [[ "${VPN_PROTOCOL}" == "tcp-client" ]]; then
			export VPN_PROTOCOL="tcp"
		fi
	else
		echo "[warn] VPN_PROTOCOL not found in ${VPN_CONFIG}, assuming udp" | ts '%Y-%m-%d %H:%M:%.S'
		export VPN_PROTOCOL="udp"
	fi

	export VPN_DEVICE_TYPE=$(cat "${VPN_CONFIG}" | grep -Po '(?<=^dev\s)[^\r\n]+')
	if [[ ! -z "${VPN_DEVICE_TYPE}" ]]; then
		echo "[info] VPN_DEVICE_TYPE defined as '${VPN_DEVICE_TYPE}'" | ts '%Y-%m-%d %H:%M:%.S'
	else
		echo "[crit] VPN_DEVICE_TYPE not found in ${VPN_CONFIG}, exiting..." | ts '%Y-%m-%d %H:%M:%.S' && exit 1
	fi

	# get values from env vars as defined by user
	export VPN_PROV=$(echo "${VPN_PROV}" | sed -e 's/^[ \t]*//')
	if [[ ! -z "${VPN_PROV}" ]]; then
		echo "[info] VPN_PROV defined as '${VPN_PROV}'" | ts '%Y-%m-%d %H:%M:%.S'
	else
		echo "[crit] VPN_PROV not defined,(via -e VPN_PROV), exiting..." | ts '%Y-%m-%d %H:%M:%.S' && exit 1
	fi

	export LAN_NETWORK=$(echo "${LAN_NETWORK}" | sed -e 's/^[ \t]*//')
	if [[ ! -z "${LAN_NETWORK}" ]]; then
		echo "[info] LAN_NETWORK defined as '${LAN_NETWORK}'" | ts '%Y-%m-%d %H:%M:%.S'
	else
		echo "[crit] LAN_NETWORK not defined (via -e LAN_NETWORK), exiting..." | ts '%Y-%m-%d %H:%M:%.S' && exit 1
	fi

	export NAME_SERVERS=$(echo "${NAME_SERVERS}" | sed -e 's/^[ \t]*//')
	if [[ ! -z "${NAME_SERVERS}" ]]; then
		echo "[info] NAME_SERVERS defined as '${NAME_SERVERS}'" | ts '%Y-%m-%d %H:%M:%.S'
	else
		echo "[warn] NAME_SERVERS not defined (via -e NAME_SERVERS), defaulting to Google and FreeDNS name servers" | ts '%Y-%m-%d %H:%M:%.S'
		export NAME_SERVERS="8.8.8.8,37.235.1.174,8.8.4.4,37.235.1.177"
	fi

	if [[ $VPN_PROV != "airvpn" ]]; then
		export VPN_USER=$(echo "${VPN_USER}" | sed -e 's/^[ \t]*//')
		if [[ ! -z "${VPN_USER}" ]]; then
			echo "[info] VPN_USER defined as '${VPN_USER}'" | ts '%Y-%m-%d %H:%M:%.S'
		else
			echo "[warn] VPN_USER not defined (via -e VPN_USER), assuming authentication via other method" | ts '%Y-%m-%d %H:%M:%.S'
		fi

		export VPN_PASS=$(echo "${VPN_PASS}" | sed -e 's/^[ \t]*//')
		if [[ ! -z "${VPN_PASS}" ]]; then
			echo "[info] VPN_PASS defined as '${VPN_PASS}'" | ts '%Y-%m-%d %H:%M:%.S'
		else
			echo "[warn] VPN_PASS not defined (via -e VPN_PASS), assuming authentication via other method" | ts '%Y-%m-%d %H:%M:%.S'
		fi
	fi

	export VPN_INCOMING_PORT=$(echo "${VPN_INCOMING_PORT}" | sed -e 's/^[ \t]*//')
	if [[ ! -z "${VPN_INCOMING_PORT}" ]]; then
		echo "[info] VPN_INCOMING_PORT defined as '${VPN_INCOMING_PORT}'" | ts '%Y-%m-%d %H:%M:%.S'
	else
		echo "[warn] VPN_INCOMING_PORT not defined (via -e VPN_INCOMING_PORT), downloads may be slow" | ts '%Y-%m-%d %H:%M:%.S'
		export VPN_INCOMING_PORT=""
	fi

	export VPN_OPTIONS=$(echo "${VPN_OPTIONS}" | sed -e 's/^[ \t]*//')
	if [[ ! -z "${VPN_OPTIONS}" ]]; then
		echo "[info] VPN_OPTIONS defined as '${VPN_OPTIONS}'" | ts '%Y-%m-%d %H:%M:%.S'
	else
		echo "[info] VPN_OPTIONS not defined (via -e VPN_OPTIONS)" | ts '%Y-%m-%d %H:%M:%.S'
		export VPN_OPTIONS=""
	fi

	if [[ $VPN_PROV == "pia" ]]; then

		export STRICT_PORT_FORWARD=$(echo "${STRICT_PORT_FORWARD}" | sed -e 's/^[ \t]*//')
		if [[ ! -z "${STRICT_PORT_FORWARD}" ]]; then
			echo "[info] STRICT_PORT_FORWARD defined as '${STRICT_PORT_FORWARD}'" | ts '%Y-%m-%d %H:%M:%.S'
		else
			echo "[warn] STRICT_PORT_FORWARD not defined (via -e STRICT_PORT_FORWARD), defaulting to 'yes'" | ts '%Y-%m-%d %H:%M:%.S'
			export STRICT_PORT_FORWARD="yes"
		fi

	fi

	export ENABLE_PRIVOXY=$(echo "${ENABLE_PRIVOXY}" | sed -e 's/^[ \t]*//')
	if [[ ! -z "${ENABLE_PRIVOXY}" ]]; then
		echo "[info] ENABLE_PRIVOXY defined as '${ENABLE_PRIVOXY}'" | ts '%Y-%m-%d %H:%M:%.S'
	else
		echo "[warn] ENABLE_PRIVOXY not defined (via -e ENABLE_PRIVOXY), defaulting to 'no'" | ts '%Y-%m-%d %H:%M:%.S'
		export ENABLE_PRIVOXY="no"
	fi

	export ENABLE_FLOOD=$(echo "${ENABLE_FLOOD}" | sed -e 's/^[ \t]*//')
	if [[ ! -z "${ENABLE_FLOOD}" ]]; then
		echo "[info] ENABLE_FLOOD defined as '${ENABLE_FLOOD}'" | ts '%Y-%m-%d %H:%M:%.S'
	else
		echo "[warn] ENABLE_FLOOD not defined (via -e ENABLE_FLOOD), defaulting to 'no'" | ts '%Y-%m-%d %H:%M:%.S'
		export ENABLE_FLOOD="no"
	fi
	
elif [[ $VPN_ENABLED == "no" ]]; then
	echo "[warn] !!IMPORTANT!! You have set the VPN to disabled, you will NOT be secure!" | ts '%Y-%m-%d %H:%M:%.S'
fi

EOF

# replace env vars placeholder string with contents of file (here doc)
sed -i '/# ENVVARS_PLACEHOLDER/{
    s/# ENVVARS_PLACEHOLDER//g
    r /tmp/envvars_heredoc
}' /root/init.sh
rm /tmp/envvars_heredoc

# cleanup
yes|pacman -Scc
rm -rf /usr/share/locale/*
rm -rf /usr/share/man/*
rm -rf /usr/share/gtk-doc/*
rm -rf /tmp/*
