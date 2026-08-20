#!/bin/bash
set -u

RED=$'\033[38;5;203m'; GREEN=$'\033[38;5;46m'; YELLOW=$'\033[38;5;226m'; CYAN=$'\033[38;5;51m'; RESET=$'\033[0m'

get_nic() {
    ip -o -4 route show to default 2>/dev/null | awk 'NR==1 {print $5}'
}

NIC="$(get_nic)"
if [ -z "$NIC" ]; then
    echo "Unable to detect the default network interface."
    exit 1
fi

if ! command -v wondershaper >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y wondershaper >/dev/null 2>&1 || true
fi

if ! command -v wondershaper >/dev/null 2>&1; then
    echo -e "${RED}wondershaper is not installed and could not be installed.${RESET}"
    exit 1
fi

state="$(cat /home/limit 2>/dev/null || true)"
clear 2>/dev/null || true
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║              MAHBOUB SERVER BANDWIDTH LIMIT                ║${RESET}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}║${RESET} Interface : ${GREEN}${NIC}${RESET}"
echo -e "${CYAN}║${RESET} Current   : ${YELLOW}${state:-OFF}${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo
printf '[1] Start / change limit\n[2] Stop limit\n[3] Back\n\nChoose: '
read -r num

case "$num" in
1)
    read -rp 'Maximum download rate (Kbps): ' down
    read -rp 'Maximum upload rate (Kbps): ' up
    [[ "$down" =~ ^[0-9]+$ && "$up" =~ ^[0-9]+$ && "$down" -gt 0 && "$up" -gt 0 ]] || {
        echo -e "${RED}Enter positive numeric Kbps values.${RESET}"; exit 1;
    }
    wondershaper -c -a "$NIC" >/dev/null 2>&1 || true
    if wondershaper -a "$NIC" -d "$down" -u "$up"; then
        printf '%s\n' start > /home/limit
        echo -e "${GREEN}Server bandwidth limit applied.${RESET}"
        echo "Download: ${down} Kbps | Upload: ${up} Kbps"
    else
        echo -e "${RED}Failed to apply bandwidth limit.${RESET}"
        exit 1
    fi
    ;;
2)
    wondershaper -c -a "$NIC" >/dev/null 2>&1 || true
    : > /home/limit
    echo -e "${GREEN}Server bandwidth limit removed.${RESET}"
    ;;
3)
    exit 0
    ;;
*)
    echo -e "${RED}Invalid option.${RESET}"
    exit 1
    ;;
esac
