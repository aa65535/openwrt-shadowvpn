#!/bin/sh

# example client down script
# will be executed when client is down

# all key value pairs in ShadowVPN config file will be passed to this script
# as environment variables, except password

# uncomment if you want to turn off IP forwarding
# sysctl -w net.ipv4.ip_forward=0

# get old gateway
echo "reading old gateway and interface name"
old_gw=$(cat /tmp/old_gw)
old_intf=$(cat /tmp/old_intf)
if [ -z "$old_gw" ] || [ -z "$old_intf" ]; then
  echo "can not read gateway or interface name, check up.sh"
  exit 1
fi

# turn off NAT over VPN and old_intf
iptables -t nat -D POSTROUTING -o $intf -j MASQUERADE
iptables -D FORWARD -i $intf -o $old_intf -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -D FORWARD -i $old_intf -o $intf -j ACCEPT

# change routing table
route del $server gw $old_gw
route del default
route add default gw $old_gw
echo "default route changed to $old_gw"

# remove chnroutes rules
if [ -f /tmp/routes ]; then
  sed -i 's#route add#route del#g' /tmp/routes
  ip -batch /tmp/routes
  rm -f /tmp/routes
  echo "remove chnroutes rules"
fi

echo "$0 done"
