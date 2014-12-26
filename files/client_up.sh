#!/bin/sh

# This script will be executed when client is up.
# All key value pairs in ShadowVPN config file will be passed to this script
# as environment variables, except password.

PID=$(cat $pidfile 2>/dev/null)
loger() {
	echo "$(date '+%c') up.$1 ShadowVPN[$PID] $2"
}

mkdir -p /tmp/shadowvpn

# Configure IP address and MTU of VPN interface
ifconfig $intf 10.7.0.2 netmask 255.255.255.0
ifconfig $intf mtu $mtu

# Get uci setting
route_mode=$(uci get shadowvpn.@shadowvpn[-1].route_mode 2>/dev/null)
route_file=$(uci get shadowvpn.@shadowvpn[-1].route_file 2>/dev/null)

# Get current gateway and interface
loger info "Get gateway and interface from route table"
eval $(ip route show | awk '/^default/ {
	for (i=1; i<=NF; i++) {
		if ($i == "via") { printf("old_gw=%s;", $(i+1)) }
		if ($i == "dev") { printf("old_intf=%s;", $(i+1)) }
	}
}')

if [ -z "$old_intf" ]; then
	loger error "Can't get interface from route table"
	exit 1
fi

# If current interface is tun, read from saved file.
if [ "$old_intf" = "$intf" ]; then
	loger notice "Reading gateway and interface from saved file"
	old_gw=$(cat /tmp/shadowvpn/old_gw 2>/dev/null)
	old_intf=$(cat /tmp/shadowvpn/old_intf 2>/dev/null)
	if [ -z "$old_intf" ]; then
		loger error "Can't read gateway or interface, check up.sh"
		exit 1
	fi
fi

# Save current value to file
echo $old_gw >/tmp/shadowvpn/old_gw
echo $old_intf >/tmp/shadowvpn/old_intf
echo $route_mode >/tmp/shadowvpn/route_mode

# Turn on NAT over VPN
loger notice "Turn on NAT over $intf"
iptables -t nat -A POSTROUTING -o $intf -j MASQUERADE
iptables -I FORWARD 1 -o $intf -j ACCEPT
iptables -I FORWARD 1 -i $intf -j ACCEPT

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
	loger notice "Default route changed to 10.7.0.1"
else
	suf="via 10.7.0.1 dev $intf"
fi

# Load route rules
if [ "$route_mode" != 0 -a -f "$route_file" ]; then
	awk -v suf="$suf" '$1 ~ /^([0-9]{1,3}\.){3}[0-9]{1,3}/\
		{printf("route add %s %s\n",$1,suf)}' $route_file >/tmp/shadowvpn/routes
	ip -batch /tmp/shadowvpn/routes
	loger notice "Route rules have been loaded"
fi

loger info "Script $0 completed"
