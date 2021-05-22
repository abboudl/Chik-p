FROM docker.elastic.co/beats/filebeat:7.10.2
COPY ./filebeat.yml /usr/share/filebeat/
USER root
RUN chown root:filebeat /usr/share/filebeat/filebeat.yml && \
    chmod 600 /usr/share/filebeat/filebeat.yml
USER filebeat 
