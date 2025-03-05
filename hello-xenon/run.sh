#!/bin/sh

PWD=$(pwd)

docker stop HelloXenon
docker rm HelloXenon
docker build -t hello-xenon .
docker run --name HelloXenon -p 80:80 -v $PWD/html:/usr/share/nginx/html hello-xenon
