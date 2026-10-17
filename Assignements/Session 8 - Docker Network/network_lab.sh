#!/bin/bash
# Session 8 - Docker Networking & Volumes lab
# Kiran N | Roll No: 10446
# Run from inside the "Session 8 - Docker Network" folder.
OUT=network_lab_output.txt
: > "$OUT"
run() { echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }
step() { echo "########## $* ##########" | tee -a "$OUT"; }

# clean up anything left from a previous run
docker rm -f frontend backend database apache-host nginx-bind >/dev/null 2>&1
docker network rm frontend-net backend-net db-net >/dev/null 2>&1
docker compose -f demo/docker-compose.yml down -v >/dev/null 2>&1
docker rm -f multi-stage-hw >/dev/null 2>&1   # frees port 8080 from Session 7
echo "Hello students" > html/index.html

step "TASK 1: Container networking"
run docker network create frontend-net
run docker network create backend-net
run docker network create db-net
run docker run -d --name frontend --network frontend-net nginx:alpine
run docker run -d --name backend --network backend-net alpine sleep infinity
run docker run -d --name database --network db-net -e MYSQL_ROOT_PASSWORD=root123 mysql:8.4
step "Add the backend container to 2 more networks"
run docker network connect frontend-net backend
run docker network connect db-net backend
run docker ps --format \"table {{.Names}}\\t{{.Image}}\\t{{.Networks}}\"
run docker network ls --filter name=-net
step "Connectivity checks"
run docker exec frontend ping -c 2 backend
run docker exec backend ping -c 2 frontend
run docker exec backend ping -c 2 database
run docker exec frontend ping -c 2 database
run "docker network inspect db-net --format '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}'"

step "TASK 1 (extra): 3-tier demo app from class with Docker Compose"
run docker compose -f demo/docker-compose.yml up -d --build
run sleep 30
run docker compose -f demo/docker-compose.yml ps
run "curl -s http://localhost:8080 | grep Roll"
run curl -s http://localhost:8080/api
run docker network ls --filter name=demo
run docker exec demo-frontend-1 getent hosts backend
run "docker exec demo-frontend-1 getent hosts database || echo 'frontend cannot resolve database (not on backend_net)'"
step "TASK 2: Host network (Apache)"
run docker run -d --name apache-host --network host httpd:alpine
run sleep 3
run curl -s http://localhost:80
run docker inspect apache-host --format \"Network mode: {{.HostConfig.NetworkMode}}\"

step "TASK 3: Bind mount (Nginx)"
run cat html/index.html
run docker run -d --name nginx-bind -p 8090:80 -v \"$PWD/html:/usr/share/nginx/html:ro\" nginx:alpine
run sleep 3
run curl -s http://localhost:8090
run echo \"Hello students - Modified by Kiran N \(10446\)!\" \> html/index.html
run curl -s http://localhost:8090
run docker ps --filter name=nginx-bind --format \"table {{.Names}}\\t{{.Status}}\\t{{.Ports}}\"

echo "Saved all output to $OUT"
