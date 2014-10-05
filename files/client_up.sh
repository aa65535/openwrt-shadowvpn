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
echo "[$(date)] reading gateway and interface name from route table"
eval $(ip route show | awk '/^default/{printf("old_gw=%s;old_intf=%s",$3,$NF)}')

# turn on NAT over VPN and old_intf
iptables -t nat -A POSTROUTING -o $intf -j MASQUERADE
iptables -A FORWARD -i $intf -o $old_intf -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $old_intf -o $intf -j ACCEPT

# if current gateway is 10.7.0.1, it indicates that our gateway is already changed
# read from saved file
if [ "x$old_gw" == "x10.7.0.1" ]; then
  echo "[$(date)] reading old gateway and old interface name"
  old_gw=$(cat /tmp/old_gw) && old_intf=$(cat /tmp/old_intf) || {
    echo "[$(date)] can not read gateway or interface name, check up.sh"
    exit 1
  }
fi

echo "[$(date)] saving old gateway and old interface name"
echo $old_gw > /tmp/old_gw
echo $old_intf > /tmp/old_intf

# change routing table
route add $server gw $old_gw
route del default
route add default gw 10.7.0.1
echo "[$(date)] default route changed to 10.7.0.1"

# chnroutes list file, You can specify a custom routes list file
chnroutes=/etc/chinadns_chnroute.txt

# insert chnroutes rules
if [ -f $chnroutes ]; then
  suf="via $old_gw dev $old_intf"
  awk -v suf="$suf" '$1 ~ /^([0-9]{1,3}\.){3}[0-9]{1,3}/\
    {printf("route add %s %s\n",$1,suf)}' $chnroutes > /tmp/routes
  ip -batch /tmp/routes
  echo "[$(date)] insert chnroutes rules"
fi

echo "[$(date)] $0 done"
