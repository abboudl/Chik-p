# CTF Services: HAProxy

## Purpose

HAProxy is "is a free, very fast and reliable solution offering high availability, load balancing, and proxying for TCP and HTTP-based applications." It augments the CTF's infrastructure by:
- Acting as a proxy to TCP-based challenges running on a private Google Kubernetes Engine (GKE) cluster
- Providing load balancing to the nodes in the cluster so that no single node is overwhelmed with connections
- Limiting the number of simultaneous connections to TCP-based challenges (netcat, SSH, etc.) 

This repository a HAProxy docker image. This service is deployed using docker-compose and Ansible as part of the automated infrastructure build process. 


## Configuration

For a full configuration and administration guide, see HAProxy's official documentation: __________. The remainder of this section will discuss important details relevant to the CTF infrastructure administrator.

### Configuration File
Nginx's configuration file is `haproxy/haproxy.cfg`. This configuration:
- Sets up a statistics panel on a user-specified port allowing the CTF Infrastructure Administrator to monitor various metrics related to challenge frontends (# of connections, bytes sent & received, blacklisted IPs, etc.) 
- Creates a `frontend` block for each TCP-based hosted challenge and limits the # of simultaneous connections to the frontend (to 50 at once in most cases). 
- Creates a `hosted-challenges-cluster` backend providing roundrobin load balancing to 3 kubernetes nodes, by default.
- Sets the timeout on each frontend to 5 mins meaning that the user is disconnected if their TCP connection is idle for 5 minutes or more.

### Frontend Blocks and Backend Blocks
HAProxy exposes frontend ports and proxies connections to hosts in the backend block in a roundrobin fashion. 

In this context, a frontend block is a port representing an entrypoint to a challenge. This port as well as the FQDN of the HAProxy host is shared with players in the challenge's instructions. 

A backend block, on the other hand, is a listing of the Kubernetes cluster nodes (i.e. hosts) where challenge pods reside. Each TCP-based challenge in Kubernetes is exposed to the world using a NodePort service. This service exposes the challenge on the same port on all Kubernetes nodes.  

The port assigned in the configuration of the Nodeport service exposing a challenge must be the same as the port assigned to the challenge's frontend block in HAProxy. In the current configuration, HAProxy, by default, passes an incoming connection to a frontend port to the same port on one backend host (based on the roundrobin loadbalancing algorithm).

To create a frontend block for a TCP-based challenge, simply add a `frontend` block like this and modify the port to one matching the port you specified in the NodePort service exposing the challenge.
```
frontend braceforltrace-sysadmin
        tcp-request connection reject if { src_conn_rate(Abuse) ge 50 }
        tcp-request connection reject if { src_conn_cur(Abuse) ge 50 }
        tcp-request connection track-sc1 src table Abuse
        bind *:30903
```

You do not need to do anything for HTTP-based challenges. Those are managed by `ingress-nginx`. See <Hosted Challenge Repo>. 


## Deployment

See <template file> and <deploy-haproxy.yml> in <> to get an understanding of how HAProxy is deployed. 

### Network Location

DMZ Subnet.

### Important Accounts, Credentials, and Secrets

During service deployment, Ansible uses the `lpass` commandline utility to retrieve passwords from a LastPass password vault. The following tables catalog all secrets related to HAProxy that must be set up in lastpass prior to the <automated infrastructure build process>.

| Account/Credential       | LastPass Credential Name        | Description                                                                          |
| -------------------------|---------------------------------|--------------------------------------------------------------------------------------|
| haproxy stats panel acct | ctf_haproxy_stats_panel_account | Username and password are set by the CTF Infrastructure Administrator. Provides access to a dashboard exposed on port 8080 for monitoring hosted challenges (bruteforcing, excessive # of connections, etc.) |

### Pre-Deployment Configuration Checklist
1. Generate secrets related to HAProxy and store them in a LastPass password vault (See "Important Accounts, Credentials, and Secrets" above.)
2. Edit `haproxy/haproxy.cfg` with:
    1. The FQDN and port of the statistics panel under `listen stats` block. Ex: `haproxy.int.ctf.issessions.ca:8080`
    2. A `frontend` for each TCP-based challenge you plan to deploy.
    3. The FQDN of each backend Kubernetes node under `backend hosted-challenges-cluster`.


### Post-Deployment Configuration Checklist
None.