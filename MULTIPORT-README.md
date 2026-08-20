# Multi-port 80/443 architecture

Public TCP ports **80** and **443** are owned only by nginx.

nginx routes WebSocket paths to private localhost services:

| Service | Public 80 | Public 443 | Backend |
|---|---:|---:|---:|
| VMess | `/vmess/` | `/vmess/` | Xray 127.0.0.1:10082 / 10081 |
| VLESS | `/vless/` | `/vless/` | Xray 127.0.0.1:10084 / 10083 |
| Trojan | `/trojan/` | `/trojan/` | Xray 127.0.0.1:10085 |
| Trojan-Go | `/trojango` | `/trojango` | 127.0.0.1:10087 |
| SSH WS | `/ssh-ws` | `/ssh-ws` | 127.0.0.1:10088 / 10089 |
| OpenVPN WS | `/ovpn-ws` | `/ovpn-ws` | 127.0.0.1:10086 |

Port 443 TLS is terminated by nginx using `/etc/xray/xray.crt` and `/etc/xray/xray.key`.
The Xray and Trojan-Go backends are therefore private and do not bind directly to 80/443.

## Important

Do not use the old port-changing scripts to independently change Xray/WS public ports. 80 and 443 are shared listeners. Change the nginx frontend and backend mapping together if a different architecture is required.


## Transport expansion

The account generators expose the requested public layout for VMess, VLESS and Trojan: XHTTP, TCP, WebSocket, HTTP Upgrade and gRPC use 443 for TLS and 80 for NTLS. Trojan-Go and SSH use WebSocket on 443/80.

HTTP-based transports are multiplexed through nginx. Raw TCP needs a protocol-aware L4 multiplexer to safely share 80/443 with HTTP transports; this build keeps raw Xray backends private and does not expose 8080/8443/8444/8445.
