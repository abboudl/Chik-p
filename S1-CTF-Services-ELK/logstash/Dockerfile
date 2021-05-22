ARG ELK_VERSION

# https://www.docker.elastic.co/
FROM docker.elastic.co/logstash/logstash:${ELK_VERSION}
COPY ./config/ /usr/share/logstash/config/
COPY ./pipeline/ /usr/share/logstash/pipeline/

USER root

RUN chown -R logstash:root /usr/share/logstash/config/

USER logstash

# Add your logstash plugins setup here
# Example: RUN logstash-plugin install logstash-filter-json
