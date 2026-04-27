wg.conf配置文件内容如下：
[Interface]
Address = 10.7.0.1/24 # 本机 WireGuard 接口分配的虚拟 IP 地址和子网掩码
PrivateKey = xxxx=
ListenPort = 2097 # 本机监听的 UDP 端口
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ens19 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ens19 -j MASQUERADE

# 远程对等体（如客户端或另一台服务器）的参数
[Peer]
PublicKey = xxxx= # 远程对等体的公钥，用于加密发送给对方的数据
PresharedKey = xxxx
AllowedIPs = 10.7.0.2/32 # 定义了哪些 IP 地址的流量可以通过这个对等体进行路由。

客户都安配置文件内容如下：
[Interface]
PrivateKey = xxxx
Address = 10.7.0.2/24
DNS = 192.168.8.1, 61.128.128.68, 61.128.192.68

[Peer]
PublicKey = xxxx
PresharedKey = xxxx
AllowedIPs = 10.7.0.1/24, 172.16.0.0/24, 192.168.8.0/24
Endpoint = 183.66.184.58:2097
PersistentKeepalive = 25