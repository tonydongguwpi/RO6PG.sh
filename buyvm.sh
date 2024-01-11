#!/bin/bash
echo -n "是否开始安装（y/n）:"
read readyToGo
if [ $readyToGo != 'y' ]
then
	echo "已退出"
	exit 0
fi
echo -n "请输入所分配到的主IPv6地址的网络号 如（2001:860:23::）: "
read mainIPv6
echo -n "请输入CIDR 如果你不知道这个的意思，则输入48: "
read CIDR
echo -n "请输入IPv6网关IP: "
read gw6
echo -n "请输入所分配的IPv6子网："
read subIPv6

apt update
apt install net-tools screen nano curl git wget -y

systemctl disable systemd-resolved
systemctl stop systemd-resolved

cat >/etc/resolv.conf<<EOF
nameserver 1.1.1.1
nameserver 2a11::
EOF

gw4=$(ip route | awk '/^default/ {print $3; exit}')
localIP=$(ifconfig -a | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | tr -d "addr:")

cp /etc/netplan/01-netcfg.yaml /etc/netplan/01-netcfg.yaml.bak
echo '' > /etc/netplan/01-netcfg.yaml
cat >/etc/netplan/01-netcfg.yaml<<EOF
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: true
      gateway4: ${gw4}
      gateway6: ${gw6}
      addresses: [${localIP}/24,'${mainIPv6}/48','${subIPv6}/48']
EOF

netplan apply
sysctl net.ipv6.ip_nonlocal_bind=1
ip route add local ${subIPv6}/${CIDR} dev lo
echo "完成隧道配置，开始安装服务端"
curl https://file.uhsea.com/2401/fb442d21c85c9f49ff208fb02979a88eYF.bak -o /usr/bin/http-random
chmod 755 /usr/bin/http-random
chmod a+x /usr/bin/http-random
sleep 3
bash <(curl -fsSL https://sing-box.app/deb-install.sh)
ufw disable
echo -n "安装完成"

screen -dmS http-random
sleep 1
screen -S http-random -X stuff "http-random -b 127.0.0.1:7777 -i ${subIPv6}/${CIDR}$(printf '\r')";
mkdir ${HOME}/sbconf
curl https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db -o ${HOME}/sbconf/geoip.db -L
touch ${HOME}/sbconf/config.json
cat >${HOME}/sbconf/config.json<<EOF
{
    "inbounds": [
        {
            "type": "mixed",
            "tag": "mixed-in",
            "listen": "0.0.0.0",
            "listen_port": 55431
        }
    ],
    "outbounds": [
    {
            "type": "block",
            "tag": "block"
    },
    {
	    "type": "http",
	    "tag": "http-out",
	    "server": "127.0.0.1",
	    "server_port": 7777
    },
    {
	    "type": "direct",
	    "tag": "direct"
    }
  ],
    "route": {
        "rules": [
	    {
		"domain_suffix": [
          		".cn"
        	],
                "outbound": "block"
            },
            {
		"ip_version": 4,
                "outbound": "direct"
            },
	    {
		"geoip": [
          		"cn"
        	],
	        "ip_version":4,
		"invert": true,
		"outbound": "http-out"
	    }
        ]
    }
}
EOF

screen -dmS singbox
sleep 1
screen -S singbox -X stuff  "cd ${HOME}/sbconf$(printf '\r')sing-box run -c ${HOME}/sbconf/config.json$(printf '\r')"

echo "HTTP/SOCKS5混合代理：${localIP}:55431"
