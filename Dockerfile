FROM centos:7 as builder

ENV LANG=en_US.utf8 LC_ALL=en_US.utf8

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r redis && useradd -r -g redis redis

RUN \
    yum install -y \
      wget \
      ca-certificates \
      bzip2 \
      curl \
      grep \
      sed \
      which \
&& \
   yum clean all

RUN \
    sed -i "s/override_install_langs=en_US.UTF-8/override_install_langs=en_US.utf8/g" /etc/yum.conf \
&&  yum groups mark install "Development Tools" \
&&  yum groups mark convert "Development Tools" \
&&  yum groupinstall -y 'Development Tools' \
&&  yum clean all

ADD software_dist/gosu /usr/local/bin
ADD software_dist/gosu.asc /usr/local/bin

RUN chmod +x /usr/local/bin/gosu
RUN gosu nobody true

ADD software_dist/redis.tar.gz /tmp

RUN \
    mv /tmp/redis-4.0.8 /usr/src/redis \
&&  cd /usr/src/redis \
# disable Redis protected mode [1] as it is unnecessary in context of Docker
# (ports are not automatically exposed when running inside Docker, but rather explicitly by specifying -p / -P)
# [1]: https://github.com/antirez/redis/commit/edd4d555df57dc84265fdfb4ef59a4678832f6da
&&	grep -q '^#define CONFIG_DEFAULT_PROTECTED_MODE 1$' /usr/src/redis/src/server.h \
&&  sed -ri 's!^(#define CONFIG_DEFAULT_PROTECTED_MODE) 1$!\1 0!' /usr/src/redis/src/server.h \
&&  grep -q '^#define CONFIG_DEFAULT_PROTECTED_MODE 0$' /usr/src/redis/src/server.h \
# for future reference, we modify this directly in the source instead of just supplying a default configuration flag because apparently "if you specify any argument to redis-server, [it assumes] you are going to specify everything"
# see also https://github.com/docker-library/redis/issues/4#issuecomment-50780840
# (more exactly, this makes sure the default behavior of "save on SIGTERM" stays functional by default)
&&  make -C /usr/src/redis -j "$(nproc)" \
&&  make PREFIX=/opt/redis -C /usr/src/redis install \
&&  rm -r /usr/src/redis

FROM centos:7 as runner

ENV LANG=en_US.utf8 LC_ALL=en_US.utf8

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r redis && useradd -r -g redis redis

RUN \
    sed -i "s/override_install_langs=en_US.UTF-8/override_install_langs=en_US.utf8/g" /etc/yum.conf \
&&  yum install -y glibc-common \
&&  yum install -y \
      wget \
      ca-certificates \
      bzip2 \
      curl \
      grep \
      sed \
      which \
&& \
   yum clean all

COPY --from=builder /usr/local/bin/gosu /usr/local/bin
COPY --from=builder /opt/redis /opt/redis

RUN mkdir /data && chown redis:redis /data
VOLUME /data
WORKDIR /data

ENV PATH=/opt/redis/bin:/usr/local/bin:${PATH}
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

EXPOSE 6379
CMD ["redis-server"]
