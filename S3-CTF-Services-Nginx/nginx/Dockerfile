ARG NGINX_VERSION

FROM nginx:${NGINX_VERSION}

# Prepare environment
RUN apt update && apt upgrade -y && \
    apt install -y bzip2 && \
    mkdir -p /etc/letsencrypt

# Copy NGINX configuration file
COPY ./nginx.conf /etc/nginx/

# Copy DH parameter into the container
COPY ./dhparam-2048.pem /etc/ssl/certs/

# Copy letsencrypt certs 
COPY ./nginx-letsencrypt-tls/ /etc/letsencrypt/

# Give necessary permissions to NGINX user
RUN chown -R nginx:nginx /var/cache/nginx/ && \
        chown -R nginx:nginx /var/log/nginx/ && \
        chown -R nginx:nginx /etc/nginx/conf.d && \
        chown -R nginx:nginx /etc/letsencrypt && \
        touch /var/run/nginx.pid && \
        chown -R nginx:nginx /var/run/nginx.pid

# Switch to non-root user
USER nginx
