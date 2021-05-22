ARG ELK_VERSION

# https://www.docker.elastic.co/
FROM docker.elastic.co/kibana/kibana:${ELK_VERSION}
COPY config/ /usr/share/kibana/config/

USER root

RUN chown -R kibana:root /usr/share/kibana/config/

USER kibana
# Add your kibana plugins setup here
# Example: RUN kibana-plugin install <name|url>
