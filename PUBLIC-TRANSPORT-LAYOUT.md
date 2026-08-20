# Public transport layout

All public client endpoints for the supported application protocols use **only TCP ports 80 and 443**.

| Protocol | Transport | TLS | NTLS |
|---|---|---:|---:|
| VLESS | XHTTP | 443 | 80 |
| VLESS | TCP | 443 | 80 |
| VLESS | WebSocket | 443 | 80 |
| VLESS | HTTP Upgrade | 443 | 80 |
| VLESS | gRPC | 443 | 80 |
| VMess | XHTTP | 443 | 80 |
| VMess | TCP | 443 | 80 |
| VMess | WebSocket | 443 | 80 |
| VMess | HTTP Upgrade | 443 | 80 |
| VMess | gRPC | 443 | 80 |
| Trojan | XHTTP | 443 | 80 |
| Trojan | TCP | 443 | 80 |
| Trojan | WebSocket | 443 | 80 |
| Trojan | HTTP Upgrade | 443 | 80 |
| Trojan | gRPC | 443 | 80 |
| Trojan-Go | WebSocket | 443 | 80 |
| SSH | WebSocket | 443 | 80 |

## Important implementation note

HTTP-based transports can share 80/443 through the nginx path multiplexer. Raw TCP transport is different: a single public 80/443 listener cannot natively distinguish VLESS, VMess, and Trojan raw streams while also serving HTTP/WebSocket/gRPC on the same port.

This revision therefore removes the old public 8080/8443/8444/8445 endpoints and keeps the raw Xray inbounds private. The generated TCP links are intentionally formatted with the requested 80/443 layout, but a protocol-aware L4 multiplexer is required before those TCP links can be genuinely functional on the shared public ports.

Trojan-Go remains WebSocket-only, as requested.
