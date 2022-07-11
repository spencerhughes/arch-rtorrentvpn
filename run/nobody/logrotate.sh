#!/usr/bin/dumb-init /bin/bash

log_path="/config/access.log"
number_of_logs_to_keep=3
file_size_limit_kb=10240

# wait for nginx process to start (listen for port)
while [[ $(netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".9080"') == "" ]]; do
	sleep 0.1
done

# wait for nginx to start logging access to file
while [[ ! -f "${log_path}" ]]; do
	sleep 0.1
done

while true; do

	file_size_kb=$(du -k "${log_path}" | cut -f1)

	if [ "${file_size_kb}" -ge "${file_size_limit_kb}" ]; then

		echo "[info] Nginx log file larger than limit ${file_size_limit_kb} kb, rotating logs..."

		if [[ -f "${log_path}.${number_of_logs_to_keep}" ]]; then
			echo "[info] Deleting oldest log file '${log_path}.${number_of_logs_to_keep}'..."
			rm -f "${log_path}.${number_of_logs_to_keep}"
		fi

		for log_number in $(seq "${number_of_logs_to_keep}" -1 0); do

			if [[ -f "${log_path}.${log_number}" ]]; then
				log_number_inc=$((log_number+1))
				mv "${log_path}.${log_number}" "${log_path}.${log_number_inc}"
			fi

		done

		echo "[info] Moving current log to ${log_path}.0..."
		mv "${log_path}" "${log_path}.0"

		echo "[info] Force Nginx to reload log files..."
		kill -USR1 $(cat /home/nobody/nginx.pid)
		sleep 1

	fi

	sleep 30s

done
