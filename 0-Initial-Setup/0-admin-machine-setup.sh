#!/usr/bin/env bash

DOCKER_COMPOSE_VERSION=1.27.4

# Make sure it's root
if [ "$EUID" -ne 0 ]; then
  echo "You must run me as root!"
  exit
fi

# Ensure all existing packages and snaps are up to date
apt-get update && apt-get -y upgrade
snap refresh

# Essentials
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg-agent \
  software-properties-common \
  openresolv

# Install docker (if not installed)
if ! [ -x "$(command -v docker)" ]; then
  curl -fsSL https://download.docker.com/linux/$(lsb_release -is | awk '{print tolower($0)}')/gpg | apt-key add - && \
  add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$(lsb_release -is | awk '{print tolower($0)}') $(lsb_release -cs) stable" && \
    apt-get update && \
    apt-get install -y docker-ce docker-ce-cli containerd.io 
fi

# Install docker-compose (if not installed)
if ! [ -x "$(command -v docker-compose)" ]; then
  curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose && \
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

# gcloud cli installation (if not installed)
if ! [ -x "$(command -v gcloud)" ]; then
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
    tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
    apt-get update && sudo apt-get install -y google-cloud-sdk
fi

# kubectl installation (if not installed)
if ! [ -x "$(command -v kubectl)" ]; then
  apt-get install -y kubectl
fi

# Ansible Installation
if ! [ -x "$(command -v ansible)" ]; then
  apt-add-repository --yes --update ppa:ansible/ansible && \
    apt install -y ansible && \
    ansible-galaxy collection install ansible.posix && \
    ansible-galaxy collection install community.general && \
    ansible-galaxy collection install community.docker && \
    ansible-galaxy collection install community.crypto
fi

# Lastpass CLI Installation
if ! [ -x "$(command -v lpass)" ]; then
  apt-get --no-install-recommends -yqq install \
    bash-completion \
    build-essential \
    cmake \
    libcurl4  \
    libcurl4-openssl-dev  \
    libssl-dev  \
    libxml2 \
    libxml2-dev  \
    libssl1.1 \
    pkg-config \
    ca-certificates \
    xclip \
    asciidoc \
    xsltproc
  git clone git@github.com:lastpass/lastpass-cli.git && \
    cd lastpass-cli && \
    make && \
    make install && \
    make install-doc && \
    cd .. && \
    rm -r lastpass-cli    
fi

# Certbot installation
snap install --classic certbot && \
snap set certbot trust-plugin-with-root=ok && \
snap install --classic certbot-dns-cloudflare && \
snap connect certbot:plugin certbot-dns-cloudflare 


# CTFd's ctfcli installation (if not installed)
git clone https://github.com/csivitu/ctfcli/ && cd ctfcli && sudo python3 setup.py install --record files.txt




