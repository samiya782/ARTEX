#!/bin/sh
# Route container TCP to 127.0.0.0/8 via a SOCKS5 proxy on the Docker host
# so destination IPs like 127.0.0.2 stay meaningful on Windows loopback.
# Host proxy default: host.docker.internal:11080 (see docker/host-socks5.py).
# Skips ARTEX ports 8787/8788. Disable with ARTEX_HOST_LOOPBACK=0.
setup_host_loopback() {
	if [ "${ARTEX_HOST_LOOPBACK:-1}" = "0" ]; then
		echo "[artex-host-loopback] disabled (ARTEX_HOST_LOOPBACK=0)"
		return 0
	fi
	if ! command -v iptables >/dev/null 2>&1; then
		echo "[artex-host-loopback] iptables not found, skip" >&2
		return 0
	fi
	if ! command -v redsocks >/dev/null 2>&1; then
		echo "[artex-host-loopback] redsocks not found, skip" >&2
		return 0
	fi
	host_ip=$(getent hosts host.docker.internal 2>/dev/null | awk '{print $1; exit}')
	if [ -z "$host_ip" ]; then
		echo "[artex-host-loopback] host.docker.internal unresolved, skip" >&2
		return 0
	fi
	socks_port="${ARTEX_HOST_SOCKS_PORT:-11080}"
	redir_port="${ARTEX_HOST_REDIR_PORT:-12345}"

	cat >/tmp/redsocks-artex.conf <<EOF
base {
	log_debug = off;
	log_info = on;
	log = "stderr";
	daemon = on;
	redirector = iptables;
}
redsocks {
	local_ip = 127.0.0.1;
	local_port = ${redir_port};
	ip = ${host_ip};
	port = ${socks_port};
	type = socks5;
}
EOF
	# Restart redsocks cleanly
	killall redsocks 2>/dev/null || true
	redsocks -c /tmp/redsocks-artex.conf

	iptables -t nat -N ARTEX_HOST_LB 2>/dev/null || true
	iptables -t nat -F ARTEX_HOST_LB
	iptables -t nat -A ARTEX_HOST_LB -p tcp --dport 8787 -j RETURN
	iptables -t nat -A ARTEX_HOST_LB -p tcp --dport 8788 -j RETURN
	iptables -t nat -A ARTEX_HOST_LB -p tcp -j REDIRECT --to-ports "$redir_port"
	iptables -t nat -C OUTPUT -d 127.0.0.0/8 -p tcp -j ARTEX_HOST_LB 2>/dev/null || \
		iptables -t nat -A OUTPUT -d 127.0.0.0/8 -p tcp -j ARTEX_HOST_LB
	echo "[artex-host-loopback] TCP 127.0.0.0/8 -> socks5://${host_ip}:${socks_port} via redsocks :${redir_port}"
}