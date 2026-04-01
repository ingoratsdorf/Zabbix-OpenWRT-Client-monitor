# Zabbix OpenWrt Clients monitor

This is a fork of @Merrick28's great work.
Available at https://github.com/Merrick28/zabbix-Openwrt-Clients-monitor.

I have done a rewrite of the template file for the latest Zabbix server version 7.4 and changed the shell scripts to lua. The discovery is about 7-8x faster that way and the client details are about 2x faster.
The actual data in Zabbix is now not queried in 4x separate steps anymore (bytes up, packets up, bytes down, packets down) but in a single step and the data is then filtered out in Zabbix as dependent items. This way, the overall data collection process is about 8x faster than it was before.

# Moved

This repo has now moved to CodeBerg: https://codeberg.org/ingoratsdorf/Zabbix-OpenWRT-Client-monitor
