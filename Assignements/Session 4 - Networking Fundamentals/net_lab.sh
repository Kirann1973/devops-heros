#!/bin/bash
# Session 4 - Networking Fundamentals lab
# Kiran N | Roll No: 10446
OUT=network_output.txt
: > "$OUT"
run() { echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }

run hostname
run hostname -I
run ip addr show
run ip route
run cat /etc/resolv.conf
run ping -c 4 google.com
run traceroute -m 15 google.com
run nslookup google.com
run dig google.com +short
run curl -sI https://www.google.com \| head -n 5
run sudo ss -tulpn
run netstat -tuln
run arp -n
run sha256sum /etc/hostname
echo "Saved all output to $OUT"
