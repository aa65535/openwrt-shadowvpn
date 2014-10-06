#!/bin/sh

# example client down script
# will be executed when client is down

# all key value pairs in ShadowVPN config file will be passed to this script
# as environment variables, except password

# uncomment if you want to turn off IP forwarding
# sysctl -w net.ipv4.ip_forward=0>/dev/null 2>&1

# turn off NAT over VPN and old gateway
/etc/init.d/firewall restart >/dev/null 2>&1

# get old gateway and old interface
echo "$(date) [DOWN] reading old gateway and old interface"
old_gw=$(cat /tmp/old_gw) && rm -f /tmp/old_gw
old_intf=$(cat /tmp/old_intf) && rm -f /tmp/old_intf
if [ -z "$old_gw" ] || [ -z "$old_intf" ]; then
  echo "$(date) [DOWN] can not read gateway or interface, check up.sh"
  exit 1
fi

# change routing table
route del $server gw $old_gw
route del default
route add default gw $old_gw
echo "$(date) [DOWN] default route changed to $old_gw"

# remove chnroute rules
if [ -f /tmp/routes ]; then
  sed -i 's#route add#route del#g' /tmp/routes
  ip -batch /tmp/routes
  rm -f /tmp/routes
  echo "$(date) [DOWN] remove chnroute rules"
fi

echo "$(date) [DOWN] done"
