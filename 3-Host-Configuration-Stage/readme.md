## Objective
The Ansible playbooks in this repository prepare the CTFd, Nginx, HAProxy, and ELK hosts for service deployment. On each host, they:
- install `docker` and `docker-compose`
- install the GCP stackdriver agent to enable detailed utilization analytics (Ex: CPU, memory, and disk).
- create the `ctf` account on each host and set its password.
- upload the `~/.ssh/ctf.pub` on the Management VM to `/home/ctf/.ssh/authorized_keys` to allow Ansible and the CTF admin to login as the `ctf` user.
- upload the CTF repository's access key (`~/.ssh/ctf-repo-key`) into `/home/ctf/.ssh/` effectively allowing the `ctf` user to pull and deploy services from Github.
- (ELK VM Only) increase the system's `vm.max_map_count` to `262144` to satisfy an Elasticsearch requirement for production clusters. 

## Prerequisites
1. All prerequisites from earlier stages.
2. You can successfully connect to the Wireguard VPN.

## Step-by-Step Instructions 

All commands must be executed on the CTF Administration machine.

### Step #1: Connect to the Wireguard VPN

Before running the playbooks in this stage, you must be connected to the CTF environment via the Wireguard VPN. Otherwise, you will not be able to reach non-internet-facing hosts such as the ELK host and the CTFd host.  

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

Ansible playbooks in this stage run under the security context of the `ansible` user on the CTFd, ELK, HAProxy, and Nginx hosts. Ansible needs to SSH as this user. To make Ansible aware of this user's identity (i.e. its private key), we add the key to the `ssh-agent`'s keychain. 

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

Ansible's `inventory.yml` file allows us to groups hosts by some property: location, organizational unit, production vs. testing, etc to allow us to perform the same action against a group. In this case, we divide hosts by subnet. We also create a group for each individual host to remove the need to edit every playbook individually if a hostname or IP changes (This is generally bad practice but in this case, our environment is small so it doesn't matter too much). We then point playbooks either to a single host, all hosts in a single subnet or all hosts in multiple subnets.
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

For example,we tell Ansible to run this playbook on all hosts in the DMZ subnet as well as the internal subnet.
```
- hosts: dmz:internal
  user: ansible
  become: yes
```

Your must edit the groups in the `inventory.yml` file to match the IP addresses or fully qualified domain names you assigned the CTFd, ELK, HAproxy, and Nginx hosts in `config.sh` in the **Cloud Resource Provisioning Stage.**

Finally, if you chose not to deploy all hosts - for example, if you decided that you do not need ELK or HAProxy - you also need to narrow down the `hosts` key in each playbook. By default, most playbooks target all hosts in the DMZ and Internal subnets.

### Step #5: Run Ansible Playbooks

You're all set! It's time to run the Ansible host configuration playbooks:

```
cd 3-Host-Configuration-Stage/
ansible-playbook 0-install-docker.yml -i inventory.yml
ansible-playbook 1-install-docker-compose.yml -i inventory.yml
ansible-playbook 2-install-stackdriver-agent.yml -i inventory.yml
ansible-playbook 3-setup-credentials.yml -i inventory.yml
ansible-playbook 4-configure-elk-vm.yml -i inventory.yml
```

or to simply run all playbooks:
```
cd 3-Host-Configuration-Stage/
chmod 700 run-all-playbooks.sh
./run-all-playbooks.sh
```

### How can I find out exactly what a notebook does?
You can find out exactly what a playbook does by simply opening it and reading the `name` key for each task.

### What do I do if a task fails?
- Go back through your configs. Search for logic errors and spelling mistakes.
- Don't worry about removing partial work. Ansible playbooks are idempotent meaning that running the same playbook over and over again will always result in the same end state.

## Next Steps
If Ansible reports no "failed" tasks, you are ready to proceed to the **Service Deployment Stage**.


