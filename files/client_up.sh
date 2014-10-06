#!/bin/sh

# example client up script
# will be executed when client is up

# all key value pairs in ShadowVPN config file will be passed to this script
# as environment variables, except password

# turn on IP forwarding
sysctl -w net.ipv4.ip_forward=1>/dev/null 2>&1

# configure IP address and MTU of VPN interface
ifconfig $intf 10.7.0.2 netmask 255.255.255.0
ifconfig $intf mtu $mtu

# get current gateway
echo "$(date) [UP] reading gateway and interface name from route table"
eval $(ip route show | awk '/^default/{printf("old_gw=%s;old_intf=%s",$3,$5)}')

# turn on NAT over VPN and old gateway
iptables -t nat -A POSTROUTING -o $intf -j MASQUERADE
iptables -A FORWARD -i $intf -o $old_intf -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $old_intf -o $intf -j ACCEPT

# if current gateway is 10.7.0.1, it indicates that our gateway
# is already changed, read from saved file.
if [ "$old_intf" == "$intf" ]; then
  echo "$(date) [UP] reading old gateway and old interface name"
  old_gw=$(cat /tmp/old_gw) && old_intf=$(cat /tmp/old_intf) || {
    echo "$(date) [UP] can not read gateway or interface name, check up.sh"
    exit 1
  }
fi

# save old gateway and old interface name
echo $old_gw > /tmp/old_gw
echo $old_intf > /tmp/old_intf
echo "$(date) [UP] saving old gateway and old interface name"

# change routing table
if [ "$old_intf" == "pppoe-wan" ]; then
  route add $server $old_intf
  suf="dev $old_intf"
else
  route add $server gw $old_gw
  suf="via $old_gw dev $old_intf"
fi
route del default
route add default gw 10.7.0.1
echo "$(date) [UP] default route changed to 10.7.0.1"

# chnroute list file, You can specify a custom routes list file
chnroute=/etc/chinadns_chnroute.txt

# insert chnroute rules
if [ -f $chnroute ]; then
  awk -v suf="$suf" '$1 ~ /^([0-9]{1,3}\.){3}[0-9]{1,3}/\
    {printf("route add %s %s\n",$1,suf)}' $chnroute > /tmp/routes
  ip -batch /tmp/routes
  echo "$(date) [UP] insert chnroute rules"
fi

echo "$(date) [UP] done"
