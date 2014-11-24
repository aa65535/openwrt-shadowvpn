OpenWrt's ShadowVPN Makefile
===

 > 编译时默认从 [clowwindy/ShadowVPN][1] 下载源码

功能说明
---

 - 添加 `chnroute` 功能, 国内流量不走 VPN

   > 默认不带 chnroute 列表文件  
   > 通过读取 ChinaDNS-C 的 [chnroute][3] 生成国内路由规则  
   > 可以修改 `/etc/shadowvpn/client_up.sh` 指定自定义路由  

编译说明
---

 - 从 OpenWrt 的 [SDK][S] 编译, [预编译 IPK 下载][2]

 > ```bash
 > # 以 ar71xx 平台为例
 > tar xjf OpenWrt-SDK-ar71xx-for-linux-x86_64-gcc-4.8-linaro_uClibc-0.9.33.2.tar.bz2
 > cd OpenWrt-SDK-ar71xx-*
 > # 获取 Makefile
 > git clone https://github.com/aa65535/openwrt-shadowvpn.git package/shadowvpn
 > # 选择要编译的包 Network -> ShadowVPN
 > make menuconfig
 > # 开始编译
 > make package/shadowvpn/compile V=99
 > ```

配置说明
---

 - VPN 网关默认为 `10.7.0.1` 需要保证此网段未被占用  

 - 强烈建议[搭配 ChinaDNS-C 使用][8], 以获得更好的使用体验  

 - 可使用 [LuCI][L] 进行配置  

相关项目
---

 Name                     | Description
 -------------------------|-----------------------------------
 [openwrt-chinadns][5]    | OpenWrt's ChinaDNS-C Makefile
 [openwrt-dnsmasq][6]     | OpenWrt's Dnsmasq Patch & Makefile
 [openwrt-shadowsocks][7] | OpenWrt's ShadowSocks Makefile
 [openwrt-dist-luci][L]   | LuCI Applications of OpenWrt-dist


  [1]: https://github.com/clowwindy/ShadowVPN
  [2]: https://sourceforge.net/projects/openwrt-dist/files/shadowvpn/
  [3]: https://github.com/aa65535/openwrt-chinadns/blob/master/files/chinadns.route
  [5]: https://github.com/aa65535/openwrt-chinadns
  [6]: https://github.com/aa65535/openwrt-dnsmasq
  [7]: https://github.com/aa65535/openwrt-shadowsocks
  [8]: https://sourceforge.net/p/openwrt-dist/wiki/Plan6/
  [S]: http://downloads.openwrt.org/snapshots/trunk/
  [L]: https://github.com/aa65535/openwrt-dist-luci
