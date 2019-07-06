#!/bin/bash

if [ ! -d "/config/pyrocore" ]; then

	# define path to pyrocore and create pyrocore config
	pyroadmin --config-dir="/config/pyrocore" --create-config &>/dev/null

else

	# define path to pyrocore config
	pyroadmin --config-dir="/config/pyrocore" &>/dev/null

fi
