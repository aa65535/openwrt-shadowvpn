#!/bin/sh

# This script will be executed when client is down.
# All key value pairs in ShadowVPN config file will be passed to this script
# as environment variables, except password.

PID=$(cat $pidfile 2>/dev/null)
loger() {
	echo "$(date '+%c') down.$1 ShadowVPN[$PID] $2"
}

# Get old value from saved file
old_gw=$(cat /tmp/shadowvpn/old_gw 2>/dev/null)
old_intf=$(cat /tmp/shadowvpn/old_intf 2>/dev/null)
route_mode=$(cat /tmp/shadowvpn/route_mode 2>/dev/null)

if [ -z "$old_intf" ]; then
	loger error "Can't get interface from saved file, check up.sh"
	exit 1
fi

# Turn off NAT over VPN
loger notice "Turn off NAT over $intf"
iptables -t nat -D POSTROUTING -o $intf -j MASQUERADE
iptables -D FORWARD -o $intf -j ACCEPT
iptables -D FORWARD -i $intf -j ACCEPT

# Change routing table
route del $server $old_intf
if [ "$route_mode" != 2 ]; then
	route del default
	if [ -z "$old_gw" ]; then
		route add default $old_intf
		loger notice "Default route changed to $old_intf"
	else
		route add default gw $old_gw
		loger notice "Default route changed to $old_gw"
	fi
fi

# Remove route rules
if [ -f /tmp/shadowvpn/routes ]; then
	sed -i 's#route add#route del#g' /tmp/shadowvpn/routes
	ip -batch /tmp/shadowvpn/routes
	loger notice "Route rules have been removed"
fi

rm -rf /tmp/shadowvpn

loger info "Script $0 completed"
