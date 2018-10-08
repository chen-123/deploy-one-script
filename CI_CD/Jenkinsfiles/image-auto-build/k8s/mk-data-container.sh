#!/usr/bin/env sh

WORKDIR="$1"

if [ -z $WORKDIR ]; then
    WORKDIR='.'
fi

cd $WORKDIR
echo "FROM debian:jessie" >./Dockerfile.data-container
echo "VOLUME [\"/data\"] " >>./Dockerfile.data-container
echo "ADD . /data" >> ./Dockerfile.data-container
echo "RUN touch /tmp/data-container.log" >> ./Dockerfile.data-container
echo "ENTRYPOINT tail -f /tmp/data-container.log " >>./Dockerfile.data-container
docker rm -f data
docker build -f ./Dockerfile.data-container -t temp/data .
docker run -d -it --name data temp/data
rm ./Dockerfile.data-container
