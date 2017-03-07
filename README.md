**Application**

[rTorrent](https://github.com/rakshasa/rtorrent)
[ruTorrent](https://github.com/Novik/ruTorrent)
[Flood](https://github.com/jfurrow/flood)
[OpenVPN](https://openvpn.net/)
[Privoxy](http://www.privoxy.org/)

**Description**

rTorrent is a quick and efficient BitTorrent client that uses, and is in development alongside, the libTorrent (not to be confused with libtorrent-rasterbar) library. It is written in C++ and uses the ncurses programming library, which means it uses a text user interface. When combined with a terminal multiplexer (e.g. GNU Screen or Tmux) and Secure Shell, it becomes a convenient remote BitTorrent client. This Docker image includes the popular ruTorrent web frontend to rTorrent for ease of use, as well as OpenVPN to ensure a secure and private connection to the Internet, including use of iptables to prevent IP leakage when the tunnel is down. Privoxy is also included to allow unfiltered access to index sites, to use Privoxy please point your application at http://<host ip>:8118.

**Build notes**

Latest stable rTorrent release from Arch Linux.
Latest stable ruTorrent release from Arch Linux AUR.
Latest GitHub commit to master branch for Flood.
Latest stable OpenVPN release from Arch Linux repo.
Latest stable Privoxy release from Arch Linux repo.

**Usage**
```
docker run -d \
    --cap-add=NET_ADMIN \
    -p 9080:9080 \
    -p 9443:9443 \
    -p 8118:8118 \
    -p 3000:3000 \
    --name=<container name> \
    -v <path for data files>:/data \
    -v <path for config files>:/config \
    -v /etc/localtime:/etc/localtime:ro \
    -e VPN_ENABLED=<yes|no> \
    -e VPN_USER=<vpn username> \
    -e VPN_PASS=<vpn password> \
    -e VPN_REMOTE=<vpn remote gateway> \
    -e VPN_PORT=<vpn remote port> \
    -e VPN_PROTOCOL=<vpn remote protocol> \
    -e VPN_DEVICE_TYPE=<tun|tap> \
    -e VPN_PROV=<pia|airvpn|custom> \
    -e VPN_OPTIONS=<additional openvpn cli options> \
    -e STRONG_CERTS=<yes|no> \
    -e ENABLE_PRIVOXY=<yes|no> \
    -e ENABLE_FLOOD=<yes|no|both> \
    -e LAN_NETWORK=<lan ipv4 network>/<cidr notation> \
    -e NAME_SERVERS=<name server ip(s)> \
    -e DEBUG=<true|false> \
    -e PHP_TZ=<php timezone> \
    -e UMASK=<umask for created files> \
    -e PUID=<uid for user> \
    -e PGID=<gid for user> \
    binhex/arch-rtorrentvpn
```

Please replace all user variables in the above command defined by <> with the correct values.

**Access ruTorrent (web ui)**

`http://<host ip>:9080/`

or

`https://<host ip>:9443/`

Username:- admin
Password:- rutorrent

**Access Flood (web ui)**

`http://<host ip>:3000/`

Note:- Requires user to enable Flood via container env var (ENABLE_FLOOD).

**Access Privoxy**

`http://<host ip>:8118`

**PIA provider**

PIA users will need to supply VPN_USER and VPN_PASS, optionally define VPN_REMOTE (list of gateways https://www.privateinternetaccess.com/pages/client-support) if you wish to use another remote gateway other than the Netherlands.

**PIA example**
```
docker run -d \
    --cap-add=NET_ADMIN \
    -p 9080:9080 \
    -p 9443:9443 \
    -p 8118:8118 \
    -p 3000:3000 \
    --name=rtorrentvpn \
    -v /root/docker/data:/data \
    -v /root/docker/config:/config \
    -v /etc/localtime:/etc/localtime:ro \
    -e VPN_ENABLED=yes \
    -e VPN_USER=myusername \
    -e VPN_PASS=mypassword \
    -e VPN_REMOTE=nl.privateinternetaccess.com \
    -e VPN_PORT=1198 \
    -e VPN_PROTOCOL=udp \
    -e VPN_DEVICE_TYPE=tun \
    -e VPN_PROV=pia \
    -e STRONG_CERTS=no \
    -e ENABLE_PRIVOXY=yes \
    -e ENABLE_FLOOD=yes \
    -e LAN_NETWORK=192.168.1.0/24 \
    -e NAME_SERVERS=8.8.8.8,8.8.4.4 \
    -e DEBUG=false \
    -e PHP_TZ=UTC \
    -e UMASK=0000 \
    -e PUID=0 \
    -e PGID=0 \
    binhex/arch-rtorrentvpn
```

**AirVPN provider**

AirVPN users will need to generate a unique OpenVPN configuration file by using the following link https://airvpn.org/generator/

AirVPN users will also need to create a port forward by using the following link https://airvpn.org/ports/ and clicking Add. This port will need to be specified in the rTorrent configuration file located at /config/rtorrent/config/rtorrent.rc with the option `port_range = <start incoming port>-<end incoming port>` and `port_random = no`.

rTorrent example config
```
port_range = 49400-49400
port_random = no
```

1. Please select Linux and then choose the country you want to connect to
2. Save the ovpn file to somewhere safe
3. Start the rtorrentvpn docker to create the folder structure
4. Stop rtorrentvpn docker and copy the saved ovpn file to the /config/openvpn/ folder on the host
5. Start rtorrentvpn docker
6. Check supervisor.log to make sure you are connected to the tunnel

**AirVPN example**
```
docker run -d \
    --cap-add=NET_ADMIN \
    -p 9080:9080 \
    -p 9443:9443 \
    -p 8118:8118 \
    -p 3000:3000 \
    --name=rtorrentvpn \
    -v /root/docker/data:/data \
    -v /root/docker/config:/config \
    -v /etc/localtime:/etc/localtime:ro \
    -e VPN_ENABLED=yes \
    -e VPN_REMOTE=nl.vpn.airdns.org \
    -e VPN_PORT=443 \
    -e VPN_PROTOCOL=udp \
    -e VPN_DEVICE_TYPE=tun \
    -e VPN_PROV=airvpn \
    -e ENABLE_PRIVOXY=yes \
    -e ENABLE_FLOOD=yes \
    -e LAN_NETWORK=192.168.1.0/24 \
    -e NAME_SERVERS=8.8.8.8,8.8.4.4 \
    -e DEBUG=false \
    -e PHP_TZ=UTC \
    -e UMASK=0000 \
    -e PUID=0 \
    -e PGID=0 \
    binhex/arch-rtorrentvpn
```

**Notes**

User ID (PUID) and Group ID (PGID) can be found by issuing the following command for the user you want to run the container as:-

```
id <username>
```

If you want to create an additional user account for ruTorrent webui then please execute the following on the host:-

```
docker exec -it <container name> /home/nobody/createuser.sh <username to create>
```

If you want to delete a user account (or change the password for an account) then please execute the following on the host:-

```
docker exec -it <container name> /home/nobody/deluser.sh <username to delete>
```

If you do not define the PHP timezone you may see issues with the ruTorrent Scheduler plugin, please make sure you set the PHP timezone by specifying this using the environment variable PHP_TZ. Valid timezone values can be found here, http://php.net/manual/en/timezones.php

The STRONG_CERTS environment variable is used to define whether to use strong certificates and enhanced encryption ciphers when connecting to PIA (does not affect other providers).
___
If you appreciate my work, then please consider buying me a beer  :D

[![PayPal donation](https://www.paypal.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=MM5E27UX6AUU4)

[Support forum](http://lime-technology.com/forum/index.php?topic=47832.0)