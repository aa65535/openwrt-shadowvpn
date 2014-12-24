#!/bin/sh

# This script will be executed when client is up.
# All key value pairs in ShadowVPN config file will be passed to this script
# as environment variables, except password.

PID=$(cat $pidfile)
loger() {
	echo "$(date '+%c') up.$1 ShadowVPN[$PID] $2"
}

# Turn on IP forwarding
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1

# Configure IP address and MTU of VPN interface
ifconfig $intf 10.7.0.2 netmask 255.255.255.0
ifconfig $intf mtu $mtu

# Get current gateway and interface
loger info "get gateway and interface from route table"
eval $(ip route show | awk '/^default/ {
	for (i=1; i<=NF; i++) {
		if ($i == "via") { printf("old_gw=%s;", $(i+1)) }
		if ($i == "dev") { printf("old_intf=%s;", $(i+1)) }
	}
}')

if [ -z "$old_intf" ]; then
	loger error "can't get interface from route table"
	exit 1
fi

# If current interface is tun, read from saved file.
if [ "$old_intf" = "$intf" ]; then
	loger notice "reading gateway and interface from saved file"
	old_gw=$(cat /tmp/old_gw) && old_intf=$(cat /tmp/old_intf)
	if [ -z "$old_intf" ]; then
		loger error "can't read gateway or interface, check up.sh"
		exit 1
	fi
fi

# Save gateway and interface to file
echo $old_gw >/tmp/old_gw
echo $old_intf >/tmp/old_intf
loger info "save gateway and interface to file"

# Turn on NAT over VPN
loger notice "turn on NAT over $intf"
iptables -t nat -A POSTROUTING -o $intf -j MASQUERADE
iptables -I FORWARD 1 -o $intf -j ACCEPT
iptables -I FORWARD 1 -i $intf -j ACCEPT

# Get uci setting
route_mode=$(uci get shadowvpn.@shadowvpn[-1].route_mode 2>/dev/null)
route_file=$(uci get shadowvpn.@shadowvpn[-1].route_file 2>/dev/null)

# Add routing table
if [ -z "$old_gw" ]; then
	route add $server $old_intf
	suf="dev $old_intf"
else
	route add $server gw $old_gw
	suf="via $old_gw dev $old_intf"
fi

# Change routing table
if [ "$route_mode" != 2 ]; then
	route del default
	route add default gw 10.7.0.1
	loger notice "default route changed to 10.7.0.1"
else
	suf="via 10.7.0.1 dev $intf"
fi

# Load route rules
if [ "$route_mode" != 0 -a -f "$route_file" ]; then
	awk -v suf="$suf" '$1 ~ /^([0-9]{1,3}\.){3}[0-9]{1,3}/\
		{printf("route add %s %s\n",$1,suf)}' $route_file >/tmp/routes
	ip -batch /tmp/routes
	loger notice "route rules have been loaded"
fi

loger info "$0 completed"
