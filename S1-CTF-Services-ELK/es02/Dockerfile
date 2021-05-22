ARG ELK_VERSION

# https://www.docker.elastic.co/
FROM docker.elastic.co/elasticsearch/elasticsearch:${ELK_VERSION}
COPY config/ /usr/share/elasticsearch/config/

RUN chown -R elasticsearch:root /usr/share/elasticsearch/config/
# Add your elasticsearch plugins setup here
# Example: RUN elasticsearch-plugin install analysis-icu
