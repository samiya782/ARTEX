#!/bin/sh
set -eu
# shellcheck disable=SC1091
. /app/host-loopback.sh

# Wait for host SOCKS so "start with stack" races are tolerated.
if [ "${ARTEX_HOST_LOOPBACK:-1}" != "0" ]; then
	socks_port="${ARTEX_HOST_SOCKS_PORT:-11080}"
	host_ip=$(getent hosts host.docker.internal 2>/dev/null | awk '{print $1; exit}')
	if [ -n "$host_ip" ] && command -v nc >/dev/null 2>&1; then
		i=0
		while [ "$i" -lt 30 ]; do
			if nc -z "$host_ip" "$socks_port" >/dev/null 2>&1; then
				break
			fi
			i=$((i + 1))
			sleep 0.2
		done
		if ! nc -z "$host_ip" "$socks_port" >/dev/null 2>&1; then
			echo "[artex-host-loopback] WARN: host SOCKS ${host_ip}:${socks_port} not reachable; 127.0.0.x targets will fail until it is up" >&2
		fi
	fi
fi

setup_host_loopback
if [ -x /app/start.sh ]; then
	exec /app/start.sh "$@"
fi
exec /app/artex "$@"