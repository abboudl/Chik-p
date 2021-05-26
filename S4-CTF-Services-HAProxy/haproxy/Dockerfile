ARG HAPROXY_VERSION

FROM haproxy:${HAPROXY_VERSION}

ENV HAPROXY_USER haproxy

RUN mkdir --parents /var/lib/${HAPROXY_USER} && \
  mkdir --parents /run/haproxy && \
  chown -R ${HAPROXY_USER}:${HAPROXY_USER} /var/lib/${HAPROXY_USER} && \
  chown -R ${HAPROXY_USER}:${HAPROXY_USER} /run/haproxy

# Copy configuration file
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg


