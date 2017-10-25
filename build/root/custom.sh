#!/bin/bash

# exit script if return code != 0
set -e

repo_name="jfurrow"
app_name="flood"
install_name="flood"
install_folder="/etc/webapps/flood"

# find latest release tag from github
/root/curly.sh -rc 6 -rw 10 -of /tmp/release_tag -url "https://github.com/${repo_name}/${app_name}/releases"
release_tag=$(cat /tmp/release_tag | grep -P -o -m 1 "(?<=/${repo_name}/${app_name}/releases/tag/)[^\"]+")

# download install zip file
/root/curly.sh -rc 6 -rw 10 -of "/tmp/${app_name}-release.zip" -url "https://github.com/${repo_name}/${app_name}/archive/${release_tag}.zip"

# unzip to /tmp
unzip "/tmp/${app_name}-release.zip" -d /tmp

# create destination directories
mkdir -p "${install_folder}/"

# move to destination folder
mv /tmp/${app_name}*/* "${install_folder}/"

# remove source zip file
rm "/tmp/${app_name}-release.zip"

# install flood
cd "${install_folder}" && npm install --production

# download htpasswd (problems with apache-tools and openssl 1.1.x)
/root/curly.sh -rc 6 -rw 10 -of /tmp/htpasswd.tar.gz -url "https://github.com/binhex/arch-packages/raw/master/compiled/htpasswd.tar.gz"

# extract compiled version of htpasswd
tar -xvf /tmp/htpasswd.tar.gz -C /
