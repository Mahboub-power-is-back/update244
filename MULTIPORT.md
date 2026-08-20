# Multi-port WebSocket architecture

Public TCP ports:
- 443: TLS/WebSocket
- 80: TLS/WebSocket (intentionally TLS on port 80 so Trojan-Go can use both public ports)

Nginx is the only public listener on 80/443. It routes by WebSocket path:
- /vmess/ -> Xray 127.0.0.1:10001
- /vless/ -> Xray 127.0.0.1:10002
- /trojan/ -> Xray 127.0.0.1:10003
- /trojango -> Trojan-Go 127.0.0.1:10004 (TLS upstream)
- /sshws/ -> SSH WebSocket 127.0.0.1:10005
- /sshnontls/ -> SSH WebSocket compatibility backend 127.0.0.1:10007
- /ovpnws/ -> OpenVPN WebSocket 127.0.0.1:10006

Port locations in source:
- Public 80/443 and WebSocket paths: ssh/vps.conf
- Xray backend ports: xray/ins-xray.sh
- WebSocket backend ports: websocket/edu.sh
- Trojan-Go backend port: xray/ins-xray.sh
- Generated client links: xray/addv2ray.sh, xray/addvless.sh, xray/addtrojan.sh, trojango/addtrgo.sh

Important:
- Do not run sslh on 80/443. It is disabled by ssh/ssh-vpn.sh because it cannot multiplex all of these WebSocket paths.
- Port 80 is TLS-enabled in this design. This is required if standard Trojan-Go WSS must work on both 80 and 443.
- OpenSSH remains on port 22; Dropbear remains on its existing SSH ports.
