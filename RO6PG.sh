#!/bin/bash
echo -n "是否开始安装（y/n）:"
read readyToGo
if [ $readyToGo != 'y' ]
then
	echo "已退出"
	exit 0
fi
echo -n "请输入所分配到的IPv6地址的网络号 如（2001:860:23:79c::）: "
read IPv6Area
echo -n "请输入CIDR 如果你不知道这个的意思，则输入64: "
read CIDR
echo -n "请输入网关IP: "
read remoteGW
touch /etc/netplan/99-he-tunnel.yaml
echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg

apt update
apt install net-tools curl grep  -y
localIP=$(ifconfig -a | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | tr -d "addr:")

cat >/etc/netplan/99-he-tunnel.yaml<<EOF
network:
  version: 2
  tunnels:
    he-ipv6:
      mode: sit
      remote: ${remoteGW}
      local: ${localIP}
      addresses:
        - "${IPv6Area}2/${CIDR}"
      routes:
        - to: default
          via: "${IPv6Area}1"
EOF
netplan apply
sysctl net.ipv6.ip_nonlocal_bind=1
ip route add local ${IPv6Area}2/${CIDR} dev lo
echo "完成隧道配置，开始安装客户端"
curl https://file.uhsea.com/2401/fb442d21c85c9f49ff208fb02979a88eYF.bak -o /usr/bin/http-random
chmod 755 /usr/bin/http-random
chmod a+x /usr/bin/http-random
echo -n "安装完成"
echo -n "http-random -b <监听IP>:<监听端口号> -i <被分配的IPv6子网>"
bash <(curl -fsSL https://sing-box.app/deb-install.sh)
ufw disable
screen -dmS http-random
sleep 1
screen -S http-random -X stuff "http-random -b 127.0.0.1:7777 -i ${IPv6Area}/${CIDR}$(printf '\r')";

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
