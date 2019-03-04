#!/bin/bash

if [ ! -d "/config/pyrocore" ]; then

	# define path to pyrocore and create pyrocore config
	pyroadmin --config-dir="/config/pyrocore" --create-config

else

	# define path to pyrocore config
	pyroadmin --config-dir="/config/pyrocore"

fi
