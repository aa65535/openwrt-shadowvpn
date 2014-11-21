#!/bin/sh

# example client down script
# will be executed when client is down

# all key value pairs in ShadowVPN config file will be passed to this script
# as environment variables, except password

PID=$(cat $pidfile)
loger() {
	echo "$(date '+%c') down.$1 ShadowVPN[$PID] $2"
}

# uncomment if you want to turn off IP forwarding
# sysctl -w net.ipv4.ip_forward=0>/dev/null 2>&1

# get old gateway and old interface
loger info "reading old gateway and old interface from saved file"
old_gw=$(cat /tmp/old_gw) && old_intf=$(cat /tmp/old_intf)

if [ -z "$old_intf" ]; then
	loger error "can't get interface from saved file, check up.sh"
	exit 1
fi

# turn off NAT over VPN
loger notice "turn off NAT over $intf and $old_intf"
iptables -t nat -D POSTROUTING -o $intf -j MASQUERADE
iptables -D FORWARD -o $intf -j ACCEPT
iptables -D FORWARD -i $intf -j ACCEPT

# change routing table
route del $server $old_intf
route del default
if [ -z "$old_gw" ]; then
	route add default $old_intf
	loger notice "default route changed to $old_intf"
else
	route add default gw $old_gw
	loger notice "default route changed to $old_gw"
fi

# remove chnroute rules
if [ -f /tmp/routes ]; then
	sed -i 's#route add#route del#g' /tmp/routes
	ip -batch /tmp/routes
	loger notice "chnroute rules have been removed"
fi

rm -f /tmp/old_gw /tmp/old_intf /tmp/routes

loger info "$0 completed"
