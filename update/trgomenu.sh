#!/bin/bash
clear
cat <<EOF
╔══════════════════════════════════════════════╗
║          MAHBOUB TUNNEL PREMIUM             ║
║               TROJAN-GO MENU                ║
╠══════════════════════════════════════════════╣
║ 1 Create  2 Delete  3 Renew  4 Check        ║
║ 5 Change Trojan-Go WS Path                   ║
║ 6 Main Menu  7 Exit                          ║
╚══════════════════════════════════════════════╝
EOF
read -rp 'Select: ' m
case $m in 1)addtrgo;;2)deltrgo;;3)renewtrgo;;4)cektrgo;;5)/usr/local/bin/trojango-change-path;;6)clear;menu;;7)exit;;*)exec "$0";;esac
