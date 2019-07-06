#!/bin/bash

if [ ! -d "/config/pyrocore" ]; then

	# define path to pyrocore and create pyrocore config
	pyroadmin --config-dir="/config/pyrocore" --create-config 1> /dev/null

else

	# define path to pyrocore config
	pyroadmin --config-dir="/config/pyrocore" 1> /dev/null

fi
