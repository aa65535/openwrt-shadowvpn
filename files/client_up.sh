#!/bin/sh

# example client up script
# will be executed when client is up

# all key value pairs in ShadowVPN config file will be passed to this script
# as environment variables, except password

PID=$(cat $pidfile)
loger() {
	echo "$(date '+%c') up.$1 ShadowVPN[$PID] $2"
}

# turn on IP forwarding
sysctl -w net.ipv4.ip_forward=1>/dev/null 2>&1

# configure IP address and MTU of VPN interface
ifconfig $intf 10.7.0.2 netmask 255.255.255.0
ifconfig $intf mtu $mtu

# get current gateway and interface
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

# if current interface is tun, read from saved file.
if [ "$old_intf" = "$intf" ]; then
	loger notice "reading gateway and interface from saved file"
	old_gw=$(cat /tmp/old_gw) && old_intf=$(cat /tmp/old_intf)
	if [ -z "$old_intf" ]; then
		loger error "can't read gateway or interface, check up.sh"
		exit 1
	fi
fi

# save gateway and interface to file
echo $old_gw >/tmp/old_gw
echo $old_intf >/tmp/old_intf
loger info "save gateway and interface to file"

# turn on NAT over VPN
loger notice "turn on NAT over $intf and $old_intf"
iptables -t nat -A POSTROUTING -o $intf -j MASQUERADE
iptables -I FORWARD 1 -o $intf -j ACCEPT
iptables -I FORWARD 1 -i $intf -j ACCEPT

# change routing table
if [ -z "$old_gw" ]; then
	route add $server $old_intf
	suf="dev $old_intf"
else
	route add $server gw $old_gw
	suf="via $old_gw dev $old_intf"
fi
route del default
route add default gw 10.7.0.1
loger notice "default route changed to 10.7.0.1"

# chnroute list file, You can specify a custom routes list file.
chnroute=/etc/chinadns_chnroute.txt

# load chnroute rules
if [ -f $chnroute ]; then
	awk -v suf="$suf" '$1 ~ /^([0-9]{1,3}\.){3}[0-9]{1,3}/\
		{printf("route add %s %s\n",$1,suf)}' $chnroute >/tmp/routes
	ip -batch /tmp/routes
	loger notice "chnroute rules have been loaded"
fi

loger info "$0 completed"
