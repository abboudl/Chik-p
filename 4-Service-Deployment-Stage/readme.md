## Purpose


## Prerequisites


## Step-by-Step Instructions 

All commands must be executed on the CTF Administration machine.

### Step #1: Connect to the Wireguard VPN

Before running the playbooks in this repository, you must be connected to the CTF's virtual private network on GCP using the Wireguard VPN. Otherwise, you will not be able to reach non-internet-facing hosts such as the ELK host and the CTFd host.  

To connect, run the Wireguard service using `systemctl`:
```
sudo systemctl start wg-quick@wg0
```

If you're not sure whether you are connected to the VPN or not, use the `status` switch to find out:
```
sudo systemctl status wg-quick@wg0
```

### Step #2: Login to Lastpass using the `lpass` Commandline Utility 

Next, you must login to Lastpass to enable Ansible to retrieve CTF passwords stored in the password vault. Run:  

```
lpass login <lastpass_login_email>
```

A prompt will appear asking you for a password. If Two-Factor Authentication (2FA) is enabled (and it should be as a best practice), a second prompt will appear requesting the 2FA code.

### Step #3: Start an SSH agent and Add SSH Keys to it Keychain

Ansible playbooks in this repository run under the security context of the `ctf` user on the CTFd, ELK, HAProxy, and Nginx hosts. Ansible needs to SSH as this user. To make Ansible aware of this user's identity (i.e. its private key), we add the key to the `ssh-agent`'s keychain. 

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

### Step #4: Edit `inventory.yml` with Target Hosts and Service Repository Owner and Names

Ansible's `inventory.yml` file allows us to groups hosts by some property: location, organizational unit, production vs. testing, etc to allow us to perform the same action against a set of hosts. In this case, we divide hosts by subnet. We also create a group for each individual host to remove the need to edit every playbook individually if a hostname or IP changes (This is generally bad practice but in this case, our environment is small so it doesn't matter too much). We then point playbooks either to a single host, all hosts in a single subnet or all hosts in multiple subnets.

We can also define variables for a particular group or host in inventory.yml. These variables are imported by any playbook that lists that group or host as a target in the playbook's `hosts` key. For every host, we define a variable identifying the owner and name of the service repository we wish to deploy to a particular host. Ansible will pull this service repository onto the target host, build the Docker images inside, and start Docker containers, effectively deploying the service.

Edit `inventory.yml` until looks similar to the following sample:
```
all:
  children:
    internal:
      hosts:
        ctfd.int.ctf.issessions.ca:                     # change me
        elk.int.ctf.issessions.ca:                      # change me
    dmz:
      hosts:
        nginx.int.ctf.issessions.ca:                    # change me
        haproxy.int.ctf.issessions.ca:                  # change me
    elk:
      hosts:
        elk.int.ctf.issessions.ca:                       # change me
          elk_git_repo_owner: abboudl                    # change me
          elk_git_repo_name: S1-CTF-Services-ELK         # change me
      hosts:
        ctfd.int.ctf.issessions.ca:                      # change me
          ctfd_git_repo_owner: abboudl                   # change me
          ctfd_git_repo_name: S2-CTF-Services-CTFd       # change me
    nginx:
      hosts:
        nginx.int.ctf.issessions.ca:                     # change me
          nginx_git_repo_owner: abboudl                  # change me
          nginx_git_repo_name: S3-CTF-Services-Nginx     # change me
    haproxy:
      hosts:
        haproxy.int.ctf.issessions.ca:                   # change me
          haproxy_git_repo_owner: abboudl                # change me
          haproxy_git_repo_name: S4-CTF-Services-HAProxy # change me

```

You must:
1. Change the hosts in inventory.yml to match the IP addresses or fully qualified domain names you assigned to the CTFd, ELK, HAproxy, and Nginx hosts in `config.sh` in [1-CTF-Infra-GCloud-Build-Scripts](https://github.com/abboudl/1-CTF-Infra-GCloud-Build-Scripts/).
2. Set name and owner of the Github repositories housing services you wish to deploy to target hosts.

These will be used to build a URL like so:
```
git clone git@github.com:{{ elk_git_repo_owner }}/{{ elk_git_repo_name }}.git
``` 

### Step #5: Generate Internal TLS Certificates

Many of the services inside the CTF environment use TLS to encrypt communication. As such, we create an internal Certificate Authority (CA) and generate certificate bundles from this CA. 
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
ansible-playbook 1-generate-cert-bundles.yml -i inventory.yml
```

Certificates bundles are written to a `./tls` in the current directory (local git repository root). Certificates bundles generated are transferred to the remote hosts by Ansible in the `*-deploy-*.yml` playbooks.
 
### Step #6: Request LetsEncrypt TLS Certificate Bundle

We also require a TLS certificate to secure communication between the scoreboard and the CTF participant's browser. If Cloudflare manages your public DNS zone, the `2-request-letsencrypt-cert-cloudflare.yml` Ansible playbook can request a certificate for you. It uses certbot's cloudflare plugin coupled with a Cloudflare API token to automate the process of requesting the certificate. Edit the `public_ctfd_fqdn` and `letsencrypt_email` at the beginning of the playbook:
```
  vars:
    public_ctfd_fqdn: "ctf.issessions.ca"                          # change me
    letsencrypt_email: "louaiabboud7@gmail.com"                    # change me
    letsencrypt_config_dir: "./tls/nginx-letsencrypt-tls/config/"
    letsencrypt_work_dir: "./tls/nginx-letsencrypt-tls/work/"
    letsencrypt_logs_dir: "./tls/nginx-letsencrypt-tls/log/"
```

Then, run it from the root of the local git repository to generate all certificates:
```
ansible-playbook 2-request-letsencrypt-cert-cloudflare.yml -i inventory.yml
```

If your DNS zone is not managed by Cloudflare, you will have to generate the letsencrypt certificate manually.

### Step #7: Complete to each Service Repository and Complete the Steps Under Pre-Deployment Prerequisites
Complete steps and push changes to Github so that when you deploy services in the next step, your changes are reflected in the deployment.

### Step #8: Deploy Services

You're all set; it's time to run the Ansible service deployment playbooks. Make sure to run them from the root of this repository.

```
ansible-playbook 3-deploy-elk.yml -i inventory.yml
ansible-playbook 4-deploy-ctfd.yml -i inventory.yml
ansible-playbook 5-deploy-nginx.yml -i inventory.yml
ansible-playbook 6-deploy-haproxy.yml -i inventory.yml
```

or to simply run all playbooks:
```
chmod 700 run-all-playbooks.sh
./run-all-playbooks.sh
```

**Important:** A description of each playbook's task can be found in the playbook itself.


## Next Steps

