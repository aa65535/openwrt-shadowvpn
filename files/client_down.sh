#!/bin/sh

# This script will be executed when client is down.
# All key value pairs in ShadowVPN config file will be passed to this script
# as environment variables, except password.

PID=$(cat $pidfile)
loger() {
	echo "$(date '+%c') down.$1 ShadowVPN[$PID] $2"
}

# Get old gateway and old interface
loger info "reading old gateway and old interface from saved file"
old_gw=$(cat /tmp/old_gw) && old_intf=$(cat /tmp/old_intf)

if [ -z "$old_intf" ]; then
	loger error "can't get interface from saved file, check up.sh"
	exit 1
fi

# Turn off NAT over VPN
loger notice "turn off NAT over $intf"
iptables -t nat -D POSTROUTING -o $intf -j MASQUERADE
iptables -D FORWARD -o $intf -j ACCEPT
iptables -D FORWARD -i $intf -j ACCEPT

# Get uci setting
route_mode=$(uci get shadowvpn.@shadowvpn[-1].route_mode 2>/dev/null)

# Change routing table
route del $server $old_intf
if [ "$route_mode" != 2 ]; then
	route del default
	if [ -z "$old_gw" ]; then
		route add default $old_intf
		loger notice "default route changed to $old_intf"
	else
		route add default gw $old_gw
		loger notice "default route changed to $old_gw"
	fi
fi

# Remove route rules
if [ -f /tmp/routes ]; then
	sed -i 's#route add#route del#g' /tmp/routes
	ip -batch /tmp/routes
	loger notice "route rules have been removed"
fi

rm -f /tmp/old_gw /tmp/old_intf /tmp/routes

loger info "$0 completed"
