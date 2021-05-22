# CTF Services: Nginx

## Purpose

Nginx is "open-source software for web serving, reverse proxying, caching, load balancing, media streaming, and more." It augments the CTF's infrastructure by:
- Acting as a reverse proxy to CTFd
- Rate-limiting connections to CTFd on a per-IP basis

This repository hosts two docker images: Nginx and Filebeat. Both services are deployed using docker-compose and Ansible as part of the infrastructure build process. 


## Configuration

For a full configuration and administration guide, see Nginx's official documentation: __________. The remainder of this section will discuss important details relevant to the CTF infrastructure administrator.

### Configuration File

Nginx's configuration file is `nginx/nginx.conf`. The default configuration:
1. redirect http to https
2. pass requests to the CTFd host on port 8000
3. set the maximum # of requests from a single IP to 40 requests per second and maximum # of connections to 15
4. configure SSL and read in a letsencrypt certificate and key for scoreboard's domain
5. Turn on the access and error log using the default "combined" logging format.
6. Set the maximum request body size to 4GB to accomodate large images in forensics challenges 

### A Note on Rate Limiting

The current configuration is suitable for a 100% online CTF. IP-based rate limiting is not practical in an on-site CTF because participants will appear under the same public IP. In this case, it may be prudent not to expose the CTF environment to the internet. Instead, host everything internally and force everyone to connect to the public Wireguard VPN in order to ensure that all participants have a different IP. 

### Filebeat Sidecar Container

A Filebeat container is used to ship logs to logstash for processing. To customize filebeat's configuration, edit `filebeat/filebeat.yml`. In the default configuration, only logs in files matching the following patterns are shipped.
- /var/log/nginx/accesses.log*
- /var/log/nginx/errors.log*

In Kibana, Nginx access and error logs will appear under the following index patterns:
- ctf-nginx-access-*
- ctf-nginx-error-*

## Deployment

See <template file> and <deploy-elk.yml> in <> to get an understanding of how Nginx is deployed. 

### Network Location

DMZ Subnet.

### Important Accounts, Credentials, and Secrets
None.

### Pre-Deployment Configuration Checklist
Edit `nginx/nginx.conf` with the following parameters. Edits must be consistent with parameters in `config.sh` in <>.
1. The FQDN and port of the backend web server hosting CTFd in the `upstream` block. Ex: `ctfd.int.ctf.issessions.ca:8000`
2. CTFd's public domain name in the second `server` block (i.e. the HTTPS block). Ex: `ctf.issessions.ca` and `www.ctf.issessions.ca`
3. The path to your letsencypt certificate and private key next `ssl_certificate` and `ssl_certificate_key`, respectively.
    1. Ex Certificate: `ssl_certificate /etc/letsencrypt/live/ctf.issessions.ca/fullchain.pem;`
    2. Ex Private Key: `ssl_certificate_key /etc/letsencrypt/live/ctf.issessions.ca/privkey.pem;`  

## Post-Deployment Configuration Checklist
None.