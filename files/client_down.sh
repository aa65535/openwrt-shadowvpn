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
echo "$(date) [DOWN] reading old gateway and old interface from saved file"
old_gw=$(cat /tmp/old_gw) && old_intf=$(cat /tmp/old_intf) || {
  echo "$(date) [DOWN] failed to get interface from saved file, check up.sh"
  exit 1
}

# change routing table
route del $server $old_intf
route del default
if [ -z "$old_gw" ]; then
  route add default $old_intf
  echo "$(date) [DOWN] default route changed to $old_intf"
else
  route add default gw $old_gw
  echo "$(date) [DOWN] default route changed to $old_gw"
fi

# remove chnroute rules
if [ -f /tmp/routes ]; then
  sed -i 's#route add#route del#g' /tmp/routes
  ip -batch /tmp/routes
  echo "$(date) [DOWN] chnroute rules removed"
fi

rm -f /tmp/old_gw /tmp/old_intf /tmp/routes

echo "$(date) [DOWN] done"
