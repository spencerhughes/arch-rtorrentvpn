#!/bin/bash

# exit script if return code != 0
set -e

flood_install_path="/etc/webapps/flood"

# download flood from master branch (no current release)
curl --connect-timeout 5 --max-time 10 --retry 5 --retry-delay 0 --retry-max-time 60 -o /tmp/flood.zip -L https://github.com/jfurrow/flood/archive/master.zip

# extract to /tmp
unzip /tmp/flood.zip -d /tmp

# create folder for flood and move to it
mkdir -p "${flood_install_path}"

mv /tmp/flood-master/* "${flood_install_path}"

# install flood
cd "${flood_install_path}" && npm install --production

# download htpasswd (problems with apache-tools and openssl 1.1.x)
curl --connect-timeout 5 --max-time 10 --retry 5 --retry-delay 0 --retry-max-time 60 -o /tmp/htpasswd.tar.gz -L https://github.com/binhex/arch-packages/raw/master/compiled/htpasswd.tar.gz

# extract compiled version of htpasswd
tar -xvf /tmp/htpasswd.tar.gz -C /
