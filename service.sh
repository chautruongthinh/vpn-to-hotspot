#!/bin/bash
if ! ip route show table 61 | grep -q "192.168.43.0/24 dev wlan0"; then
	VPN=""
	while [ "$VPN" = "" ]; do
		if ifconfig | grep -q "tun0" && ifconfig | grep -q "wlan1"; then
			echo "Giao diện tun0 và wlan0 đã sẵn sàng, thiết lập iptables..."

			# Xóa các quy tắc cũ
			iptables -t filter -F FORWARD
			iptables -t nat -F POSTROUTING

			# Thiết lập quy tắc FORWARD và NAT
			iptables -t filter -I FORWARD -j ACCEPT
			iptables -t nat -I POSTROUTING -j MASQUERADE

			# Thêm tuyến đường và quy tắc định tuyến
			ip route add 192.168.43.0/24 dev wlan0 scope link table 61
			ip rule add fwmark 0x61 table 61
			ip rule add iif tun0 table 61

			# Định tuyến lưu lượng cụ thể qua VPN
			# 1. Định tuyến DNS qua VPN
			iptables -t mangle -A PREROUTING -p tcp -d 8.8.8.8/32 -j MARK --set-xmark 0x61
			iptables -t mangle -A PREROUTING -p tcp -d 8.8.4.4/32 -j MARK --set-xmark 0x61
			iptables -t mangle -A PREROUTING -p udp -d 8.8.8.8/32 -j MARK --set-xmark 0x61
			iptables -t mangle -A PREROUTING -p udp -d 8.8.4.4/32 -j MARK --set-xmark 0x61

			# 2. Định tuyến trang web không bảo mật qua VPN
			iptables -t mangle -A PREROUTING -p tcp --dport 80 -j MARK --set-xmark 0x61
			
			# Hoàn tất thiết lập
			VPN="Done"
		else
			sleep 1
		fi
	done
else
	echo "Da chay srcipt thanh cong"
fi