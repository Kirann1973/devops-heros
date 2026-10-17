#!/bin/bash
# Session 6 & 7 - build and run every Docker app, then verify "Hello World"
# Kiran N | Roll No: 10446
# Run from inside the "Session 6-7 docker" folder.
OUT=docker_output.txt
: > "$OUT"
log() { echo "$*" | tee -a "$OUT"; }

# name : folder : host port : container port
APPS=(
  "nodejs-app:nodejs-app:3001:3000"
  "python-app:python-app:5001:5000"
  "java-app:java-app:8081:8080"
  "apache-app:Apache-app:8082:80"
  "react-app:React-app:8083:80"
  "nginx-app:nginx-app:8084:80"
  "multi-stage-hw:multi-stage-dockerfile:8080:3000"
)

for entry in "${APPS[@]}"; do
  IFS=: read -r name dir hport cport <<< "$entry"
  log "========== $name ($dir) =========="
  log "\$ docker build -t $name ./$dir"
  docker build -q -t "$name" "./$dir" 2>&1 | tee -a "$OUT"
  docker rm -f "$name" >/dev/null 2>&1
  log "\$ docker run -d --name $name -p $hport:$cport $name"
  docker run -d --name "$name" -p "$hport:$cport" "$name" 2>&1 | tee -a "$OUT"
done

log ""
log "Waiting for the apps to start..."
sleep 8

log ""
log "========== VERIFY: curl each app =========="
for entry in "${APPS[@]}"; do
  IFS=: read -r name dir hport cport <<< "$entry"
  log "\$ curl -s http://localhost:$hport"
  code=$(curl -s -o /tmp/page.html -w "%{http_code}" "http://localhost:$hport")
  text=$(grep -oE "Hello World[^<]*|<title>[^<]*" /tmp/page.html | head -1 | sed 's/<title>/title: /')
  log "HTTP $code  $text"
done

log ""
log "========== docker ps =========="
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | tee -a "$OUT"

log ""
log "========== docker images =========="
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -E "REPOSITORY|app|multi-stage" | tee -a "$OUT"

log ""
log "Saved all output to $OUT"
