## Objective
The Ansible playbooks in this repository prepare the CTFd, Nginx, HAProxy, and ELK hosts for service deployment. On each host, they:
- install `docker` and `docker-compose`
- install the GCP stackdriver agent to enable detailed resource consumption analytics (Ex: CPU, memory, and disk utilization).
- create the `ctf` account on each host and set its password.
- upload the `ctf` user's public key (`~/.ssh/ctf.pub`) to `/home/ctf/.ssh/authorized_keys` so that we can login as this user from the Management VM
- upload the CTF Github repository's access key (`~/.ssh/ctf-repo-key`) into `/home/ctf/.ssh/` effectively allowing the `ctf` user to pull and deploy services from Github.

Specifically for the ELK VM, a playbook increases

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

Ansible playbooks in this repository run under the security context of the `ansible` user on the CTFd, ELK, HAProxy, and Nginx hosts. Ansible needs to SSH as this user. To make Ansible aware of this user's identity (i.e. its private key), we add the key to the `ssh-agent`'s keychain. 

Check if the ssh-agent is running:
```
ps -aux | grep ssh-agent
```

If not, you can start one using:
```
eval `ssh-agent`
```

Next, check if the agent already has the `ansible` user's private key -- `~/.ssh/ansible` -- added to the its keychain. You can check by running the following command:
```
ssh-add -l
```

If they are already added, continue to Step #4. If they are not added, run:

```
ssh-add ~/.ssh/ansible
```

### Step #4: Set Ansible's Target Hosts in `inventory.yml` 

Ansible's `inventory.yml` file allows us to groups hosts by some property: location, organizational unit, production vs. testing, etc to allow us to perform the same action against a set of hosts. In this case, we divide hosts by subnet. We also create a group for each individual host to remove the need to edit every playbook individually if a hostname or IP changes (This is generally bad practice but in this case, our environment is small so it doesn't matter too much). We then point playbooks either to a single host, all hosts in a single subnet or all hosts in multiple subnets.
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
        haproxy.int.ctf.issessions.ca

```

For example, in this playbook, we tell Ansible to run this playbook on all hosts in the DMZ subnet as well as the internal subnet under the security context of the `ansible` user.
```
- hosts: dmz:internal
  user: ansible
  become: yes
```

Your must edit the groups in the `inventory.yml` file to match the IP addresses or fully qualified domain names you assigned the CTFd, ELK, HAproxy, and Nginx hosts in `config.sh` in [1-CTF-Infra-GCloud-Build-Scripts](https://github.com/abboudl/1-CTF-Infra-GCloud-Build-Scripts/).


### Step #5: Run Ansible Playbooks

You're all set; it's time to run the Ansible host configuration playbooks:

```
ansible-playbook 0-install-docker.yml -i inventory.yml
ansible-playbook 1-install-docker-compose.yml -i inventory.yml
ansible-playbook 2-install-stackdriver-agent.yml -i inventory.yml
ansible-playbook 3-setup-credentials.yml -i inventory.yml
ansible-playbook 4-configure-elk-vm.yml -i inventory.yml
```

or to simply run all playbooks:
```
chmod 700 run-all-playbooks.sh
./run-all-playbooks.sh
```

**Important:** A description of each playbook's task can be found in the playbook itself.


## Next Steps


