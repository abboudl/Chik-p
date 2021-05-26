ARG ELK_VERSION

FROM docker.elastic.co/beats/filebeat:${ELK_VERSION}
COPY ./filebeat.yml /usr/share/filebeat/
COPY ./ca.crt /usr/share/filebeat/
USER root
RUN chown root:filebeat /usr/share/filebeat/filebeat.yml && \
    chmod 600 /usr/share/filebeat/filebeat.yml
USER filebeat 
