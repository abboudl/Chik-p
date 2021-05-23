## Objective
The Ansible playbooks in this repository deploy the CTFd, Nginx, HAProxy, and ELK containers to their respective host. On the CTF administration VM, they:
- Create a Certificate Authority (CA) for the CTF environment and generate TLS certificates for all services
- (Optional) Use Certbot's Cloudflare plugin to request a LetsEncypt certificate for the scoreboard

Then on each remote host, they:
- Clone the Chik-p Github respoitory
- Pull the relevant service's secrets from LastPass to create a `.env` secrets file
- Transfer the `.env` secrets file to that service's folder on the remote host where it can be read by `docker-compose`. For example, `/home/ctf/Chik-p/S1-CTF-Services-ELK/`.
- Transfer any needed TLS certificates that service's folder into the proper location expected by that service's `Dockerfile`.
- Build the service's `docker` image and start the container.

## Prerequisites
1. All prerequisites from earlier stages.
2. You can successfully connect to the Wireguard VPN.

## Step-by-Step Instructions 

All commands must be executed on the CTF Administration VM.

### Step #1: Go to each Service's Folder and Complete the Steps under "Pre-Deployment Configuration Checklist"
1. Go to each service's folder (Ex: S1-CTF-Services-ELK).
2. Spend some reading the service's documentation
3. Before proceeding to step #2, complete the steps under "Pre-Deployment Configuration Checklist" and save your changes by committing to your private Chik-p Github repository.

### Step #2: Connect to the Wireguard VPN

Before running the playbooks in this stage, you must be connected to the CTF environment via the Wireguard VPN. Otherwise, you will not be able to reach non-internet-facing hosts such as the ELK host and the CTFd host.  

To connect, run the Wireguard service using `systemctl`:
```
sudo systemctl start wg-quick@wg0
```

If you're not sure whether you are connected to the VPN or not, use the `status` switch to find out:
```
sudo systemctl status wg-quick@wg0
```

### Step #3: Login to Lastpass using the `lpass` Commandline Utility 

Next, you must login to Lastpass to enable Ansible to retrieve CTF passwords stored in the password vault. Run:  

```
lpass login <lastpass_login_email>
```

A prompt will appear asking you for a password. If Two-Factor Authentication (2FA) is enabled (and it should be as a best practice), a second prompt will appear requesting the 2FA code.

### Step #4: Start an SSH agent and Add SSH Keys to it Keychain

Ansible playbooks in this stage run under the security context of the `ctf` user on the CTFd, ELK, HAProxy, and Nginx hosts. Ansible needs to SSH as this user. To make Ansible aware of this user's identity (i.e. its private key), we add the key to the `ssh-agent`'s keychain. 

Check if the ssh-agent is running:
```
ps -aux | grep ssh-agent
```

If not, you can start one using:
```
eval `ssh-agent`
```

Next, check if the agent already has the `ctf` user's private key -- `~/.ssh/ctf` -- added to the its keychain. You can check by running the following command:
```
ssh-add -l
```

If they are already added, continue to Step #4. If they are not added, run:

```
ssh-add ~/.ssh/ctf
```

### Step #5: Edit `inventory.yml` with Target Hosts and Private Chik-p Repository Name and Owner

Edit `inventory.yml`. You must:
1. Change the hosts in inventory.yml to match the IP addresses or fully qualified domain names you assigned to the CTFd, ELK, HAproxy, and Nginx hosts in `config.sh` in the **Cloud Resource Provisioning Stage**.
2. Set name and owner of the Github repositories housing services you wish to deploy to target hosts.

These will be used to build a URL like so:
```
git clone git@github.com:{{ chikp_git_repo_owner }}/{{ chikp_git_repo_name }}.git
``` 

Your `inventory.yml` file should look like the following sample.
```
all:
  children:
    internal:
      hosts:
        ctfd.int.ctf.issessions.ca: 
        elk.int.ctf.issessions.ca: 
    dmz:
      hosts:
        nginx.int.ctf.issessions.ca: 
        haproxy.int.ctf.issessions.ca: 
    elk:
      hosts:
        elk.int.ctf.issessions.ca:
    ctfd:
      hosts:
        ctfd.int.ctf.issessions.ca: 
    nginx:
      hosts:
        nginx.int.ctf.issessions.ca:
    haproxy:
      hosts:
        haproxy.int.ctf.issessions.ca:
  vars:
    chikp_git_repo_name: Chik-p           # change me
    chikp_git_repo_owner: abboudl         # change me

```

### Step #6: Generate Internal TLS Certificates

Many of the services inside the CTF environment use TLS to encrypt traffic. As such, we create an internal Certificate Authority (CA) and generate certificate bundles for services in the environment. 

First, edit the variables at the top of `1-generate-cert-bundles.yml`:
```
- hosts: localhost
  vars:
    ca_common_name: "ca.int.ctf.issessions.ca"     # change me
    elk_internal_fqdn: "elk.int.ctf.issessions.ca" # change me
    elk_private_ip: "10.10.20.51"                  # change me
```

Then, run the following playbook from the root of the local git repository to generate all certificates:
```
cd 4-Service-Deployment-Stage/
ansible-playbook 1-generate-cert-bundles.yml -i inventory.yml
```

Certificates bundles are written to a `./tls` in the current directory (local git repository root). Certificates bundles generated are transferred to the remote hosts by Ansible in the `*-deploy-*.yml` playbooks.
 
### Step #7: Request LetsEncrypt TLS Certificate Bundle

We also require a TLS certificate to secure communication between the scoreboard and the CTF participant's browser. If Cloudflare manages your public DNS zone, the `2-request-letsencrypt-cert-cloudflare.yml` Ansible playbook can request a certificate for you. It uses certbot's cloudflare plugin coupled with a Cloudflare API token to automate the process of requesting the certificate. Edit the `public_ctfd_fqdn` and `letsencrypt_email` at the beginning of the playbook:
```
  vars:
    public_ctfd_fqdn: "ctf.issessions.ca"                              # change me
    letsencrypt_email: "abboudl@example.ca"                            # change me
    letsencrypt_config_dir: "./tls/nginx-letsencrypt-tls/config/"
    letsencrypt_work_dir: "./tls/nginx-letsencrypt-tls/work/"
    letsencrypt_logs_dir: "./tls/nginx-letsencrypt-tls/log/"
```

Then, run it from the root of the local git repository to generate all certificates:
```
ansible-playbook 2-request-letsencrypt-cert-cloudflare.yml -i inventory.yml
```

If your DNS zone is not managed by Cloudflare, you will have to generate the letsencrypt certificate manually and modify the Nginx config and the Nginx Dockerfile to point to it.

### Step #8: Deploy Services

You're all set; it's time to run the Ansible service deployment playbooks.

```
cd 4-Service-Deployment-Stage/
ansible-playbook 3-deploy-elk.yml -i inventory.yml
ansible-playbook 4-deploy-ctfd.yml -i inventory.yml
ansible-playbook 5-deploy-nginx.yml -i inventory.yml
ansible-playbook 6-deploy-haproxy.yml -i inventory.yml
```

or to simply run all playbooks:
```
cd 4-Service-Deployment-Stage/
chmod 700 run-all-playbooks.sh
./run-all-playbooks.sh
```

**Important:** A description of each playbook's task can be found in the playbook itself.



## Next Steps

The Infrastructure Build Process is complete. 
1. Verify that you can connect to CTFd in a browser. Using the current configuration as an example, we would visit `https://ctf.issessions.ca`.
2. Verify that you can connect to Kibana in a browser while connected to the VPN. Using the current configuration as an example, we would visit `https://elk.int.ctf.issessions.ca:5601`.

Now it's time for application configuration. Go to each service's dedicated folder and complete the steps under **Post-Deployment Configuration Checklist** to prepare each individual service for game day.



