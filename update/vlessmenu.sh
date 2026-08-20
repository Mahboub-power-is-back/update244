#!/bin/bash
clear
cat <<EOF
╔══════════════════════════════════════════════╗
║          MAHBOUB TUNNEL PREMIUM             ║
║                 VLESS MENU                  ║
╠══════════════════════════════════════════════╣
║ 1 Create  2 Delete  3 Renew  4 Check        ║
║ 5 Change Xray WS Paths                       ║
║ 6 Main Menu  7 Exit                          ║
╚══════════════════════════════════════════════╝
EOF
read -rp 'Select: ' m
case $m in 1)addvless;;2)delvless;;3)renewvless;;4)cekvless;;5)/usr/local/bin/xray-change-path;;6)clear;menu;;7)exit;;*)exec "$0";;esac
