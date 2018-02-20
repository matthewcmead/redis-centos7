#!/usr/bin/env bash

export REDIS_VERSION=4.0.8
export REDIS_DOWNLOAD_URL=http://download.redis.io/releases/redis-4.0.8.tar.gz
export REDIS_DOWNLOAD_SHA=ff0c38b8c156319249fec61e5018cf5b5fe63a65b61690bec798f4c998c232ad
export GOSU_VERSION=1.10

export GNUPGHOME="$(mktemp -d)"

yum install -y gnupg wget

cd /project/software_dist && wget -O redis.tar.gz "$REDIS_DOWNLOAD_URL"
echo "$REDIS_DOWNLOAD_SHA *redis.tar.gz" | sha256sum -c - || REDIS_EXIT=1
if [ X$REDIS_EXIT == X1 ]; then
  echo "redis sha256sum failed"
  rm -rf redis.tar.gz
  exit 1
fi

wget -O gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64"
wget -O gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64.asc"
gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4
gpg --batch --verify gosu.asc gosu || GOSU_EXIT=1
if [ X$GOSU_EXIT == X1 ]; then
  echo "gosu gnupg signature verify failed"
  rm -f gosu*
  exit 1
fi

