#!/bin/bash
clear
cat <<EOF
╔══════════════════════════════════════════════╗
║          MAHBOUB TUNNEL PREMIUM             ║
║                 VMESS MENU                  ║
╠══════════════════════════════════════════════╣
║ 1 Create  2 Delete  3 Renew  4 Check        ║
║ 5 Change Xray WS Paths  6 Renew Cert         ║
║ 7 Main Menu  8 Exit                          ║
╚══════════════════════════════════════════════╝
EOF
read -rp 'Select: ' m
case $m in 1)addvmess;;2)delvmess;;3)renewvmess;;4)cekvmess;;5)/usr/local/bin/xray-change-path;;6)certv2ray;;7)clear;menu;;8)exit;;*)exec "$0";;esac
