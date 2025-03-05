#!/bin/sh

docker stop HelloXenon
docker rm HelloXenon
docker build -t hello-xenon .
docker run --name HelloXenon -p 80:80 -v /home/xs514-swabho/Documents/L2/Cloud\ Task/HelloXenon/html:/usr/share/nginx/html hello-xenon
