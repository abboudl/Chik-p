#!/usr/bin/env bash

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
ENDCOLOR="\e[0m"

# Check that the user has entered the correct number of parameters
if [ "$#" -ne 1 ]; then
  echo "Usage: 3-build-scoreboard-component.sh [up|down]"
  exit 1
fi

# Set the script mode to the first argument
SCRIPT_MODE="$1"

# Read configuration from global config file
source config.sh 

# Build or tear down based on the provided script mode
if [ "$SCRIPT_MODE" = "up" ]; then

  # Reserve Static External IP Addresses
  ## Nginx Host Static External Public IP
  echo -e "\n${GREEN}>>>Reserving Nginx Host Public Static IP<<<${ENDCOLOR}"
  gcloud compute addresses create "nginx-external-static-ip" \
  --region "$GCP_REGION"

  ## Save Nginx External Public IP
  NGINX_PUBLIC_IP=$( \
    gcloud compute addresses list \
      --filter="NAME='nginx-external-static-ip'" \
      --format="value(address)" | tr -d '\n' \
  )

  # Reserve Static Internal IP Addresses
  ## CTFD Host Internal IP
  echo -e "\n${GREEN}>>>Reserving CTFd Host Private Static IP ($CTFD_INTERNAL_IP)<<<${ENDCOLOR}"
  gcloud compute addresses create "ctfd-internal-static-ip" \
    --region "$GCP_REGION" --subnet "$INTERNAL_SUBNET_ID" \
    --addresses "$CTFD_INTERNAL_IP"

  ## Nginx Host Internal IP
  echo -e "\n${GREEN}>>>Reserving Nginx Host Private Static IP ($NGINX_INTERNAL_IP)<<<${ENDCOLOR}"
  gcloud compute addresses create "nginx-internal-static-ip" \
    --region "$GCP_REGION" --subnet "$DMZ_SUBNET_ID" \
    --addresses "$NGINX_INTERNAL_IP"

  # Create DNS Records
  ## Start Transaction
  gcloud dns record-sets transaction start \
     --zone="$INTERNAL_DNS_ZONE_ID" \
     --transaction-file="./transaction.yaml"

  ## Nginx A Record
  echo -e "\n${GREEN}>>>Creating a DNS A Record mapping ${CTFD_INTERNAL_IP} to ${CTFD_INTERNAL_HOSTNAME}.${INTERNAL_DNS_ZONE_DOMAIN}<<<${ENDCOLOR}"
  gcloud dns record-sets transaction add "$CTFD_INTERNAL_IP" \
     --name="$CTFD_INTERNAL_HOSTNAME.$INTERNAL_DNS_ZONE_DOMAIN" \
     --ttl="300" \
     --type="A" \
     --zone="$INTERNAL_DNS_ZONE_ID"

  ## CTFD A Record
  echo -e "\n${GREEN}>>>Creating a DNS A Record mapping ${NGINX_INTERNAL_IP} to ${NGINX_INTERNAL_HOSTNAME}.${INTERNAL_DNS_ZONE_DOMAIN}<<<${ENDCOLOR}"
  gcloud dns record-sets transaction add "$NGINX_INTERNAL_IP" \
     --name="$NGINX_INTERNAL_HOSTNAME.$INTERNAL_DNS_ZONE_DOMAIN" \
     --ttl="300" \
     --type="A" \
     --zone="$INTERNAL_DNS_ZONE_ID"

  ## Execute Transaction
  gcloud dns record-sets transaction execute \
     --zone="$INTERNAL_DNS_ZONE_ID" \
     --transaction-file="./transaction.yaml"
 
  # Create VMs
  ## CTFD Application, Database, and Redis Cache Host
  echo -e "\n${GREEN}>>>Creating CTFd Host (${CTFD_INTERNAL_HOSTNAME}.${INTERNAL_DNS_ZONE_DOMAIN})<<<${ENDCOLOR}"
  gcloud compute instances create "$CTFD_HOST_ID" \
    --hostname="$CTFD_INTERNAL_HOSTNAME.$INTERNAL_DNS_ZONE_DOMAIN" \
    --description="VM instance will host ISSessionsCTF CTFd containers including the CTFd Flask application, a MariaDB MySQL database, and a Redis cache." \
    --zone="$GCP_ZONE" \
    --machine-type="$CTFD_MACHINE_TYPE" \
    --subnet="$INTERNAL_SUBNET_ID" \
    --private-network-ip="$CTFD_INTERNAL_IP" \
    --no-address \
    --maintenance-policy="MIGRATE" \
    --image="$CTFD_MACHINE_IMAGE" \
    --image-project="$CTFD_MACHINE_IMAGE_PROJECT" \
    --boot-disk-size="$CTFD_MACHINE_DISK_SIZE" \
    --boot-disk-type="$CTFD_MACHINE_DISK_TYPE" \
    --boot-disk-device-name="ctfd" \
    --reservation-affinity="any" \
    --tags="ctfd-server" \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --metadata-from-file=ssh-keys="$ANSIBLE_PUBLIC_KEY_PATH"
    
  ## Nginx Host
  echo -e "\n${GREEN}>>>Creating Nginx Host (${NGINX_INTERNAL_HOSTNAME}.${INTERNAL_DNS_ZONE_DOMAIN})<<<${ENDCOLOR}"
  gcloud compute instances create "$NGINX_HOST_ID" \
    --hostname="$NGINX_INTERNAL_HOSTNAME.$INTERNAL_DNS_ZONE_DOMAIN" \
    --description="VM instance will host ISSessionsCTF Nginx container acting as a reverse proxy to CTFd." \
    --zone="$GCP_ZONE" \
    --machine-type="$NGINX_MACHINE_TYPE" \
    --subnet="$DMZ_SUBNET_ID" \
    --private-network-ip="$NGINX_INTERNAL_IP" \
    --address="$NGINX_PUBLIC_IP" \
    --network-tier="PREMIUM" \
    --maintenance-policy="MIGRATE" \
    --tags="nginx-server" \
    --image="$NGINX_MACHINE_IMAGE" \
    --image-project="$NGINX_MACHINE_IMAGE_PROJECT" \
    --boot-disk-size="$NGINX_MACHINE_DISK_SIZE" \
    --boot-disk-type="$NGINX_MACHINE_DISK_TYPE" \
    --boot-disk-device-name="nginx" \
    --reservation-affinity="any" \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --metadata-from-file=ssh-keys="$ANSIBLE_PUBLIC_KEY_PATH"

  # Firewall 
  ## Allow HTTP Access to Nginx
  echo -e "\n${GREEN}>>>Creating Firewall Rule: Allow Any (0.0.0.0/0) to NGINX Host on port 80<<<${ENDCOLOR}"
  gcloud compute firewall-rules create "nginx-allow-http-80" \
    --direction="INGRESS" \
    --priority="1000" \
    --network="$VPC_NETWORK" \
    --action="ALLOW" \
    --rules="tcp:80" \
    --source-ranges="0.0.0.0/0" \
    --target-tags="nginx-server"

  ## Allow HTTPS Access to Nginx
  echo -e "\n${GREEN}>>>Creating Firewall Rule: Allow Any (0.0.0.0/0) to NGINX Host on port 443<<<${ENDCOLOR}"
  gcloud compute firewall-rules create "nginx-allow-https-443" \
    --direction="INGRESS" \
    --priority="1000" \
    --network="$VPC_NETWORK" \
    --action="ALLOW" \
    --rules="tcp:443" \
    --source-ranges="0.0.0.0/0" \
    --target-tags="nginx-server"

  ## Allow Communication Between Nginx and CTFD
  echo -e "\n${GREEN}>>>Creating Firewall Rule: Allow Connections from NGINX to CTFd on port 8000 (CTFd's Default Port)<<<${ENDCOLOR}"
  gcloud compute firewall-rules create "allow-nginx-to-ctfd" \
    --direction="INGRESS" \
    --priority="1000" \
    --network="$VPC_NETWORK" \
    --action="ALLOW" \
    --rules="tcp:8000" \
    --source-tags="nginx-server" \
    --target-tags="ctfd-server"

  # Communicate Important Information
  echo -e "\n${YELLOW}>>>Next Step: Add a DNS A record on your public domain's DNS portal"\
	  "mapping ${PUBLIC_CTF_SUBDOMAIN}.${PUBLIC_DOMAIN} to the Nginx's Public IP: ${NGINX_PUBLIC_IP}<<<${ENDCOLOR}"
  

elif [ "$SCRIPT_MODE" = "down" ]; then

  # Delete Firewall Rules
  echo -e "\n${RED}>>>Deleting Firewall Rule Allowing Connections from NGINX to CTFd on port 8000 (CTFd's Default Port)<<<${ENDCOLOR}"
  gcloud compute firewall-rules delete "allow-nginx-to-ctfd" --quiet
  echo -e "\n${RED}>>>Deleting Firewall Rule Allowing Any (0.0.0.0/0) to NGINX Host on port 443<<<${ENDCOLOR}"
  gcloud compute firewall-rules delete "nginx-allow-https-443" --quiet
  echo -e "\n${RED}>>>Deleting Firewall Rule Allowing Any (0.0.0.0/0) to NGINX Host on port 80<<<${ENDCOLOR}"
  gcloud compute firewall-rules delete "nginx-allow-http-80" --quiet

  # Delete Hosts
  echo -e "\n${RED}>>>Deleting CTFd Host (${CTFD_INTERNAL_HOSTNAME}.${INTERNAL_DNS_ZONE_DOMAIN})<<<${ENDCOLOR}"
  gcloud compute instances delete "$CTFD_HOST_ID" --quiet --zone="$GCP_ZONE"
  echo -e "\n${RED}>>>Deleting Nginx Host (${NGINX_INTERNAL_HOSTNAME}.${INTERNAL_DNS_ZONE_DOMAIN})<<<${ENDCOLOR}"
  gcloud compute instances delete "$NGINX_HOST_ID" --quiet --zone="$GCP_ZONE"

  # Delete DNS Records
  ## Start Transaction
  gcloud dns record-sets transaction start \
    --zone="$INTERNAL_DNS_ZONE_ID" \
    --transaction-file="./transaction.yaml"

  ## Remove CTFD A Record
  echo -e "\n${RED}>>>Deleting DNS A Record mapping ${CTFD_INTERNAL_IP} to ${CTFD_INTERNAL_HOSTNAME}.${INTERNAL_DNS_ZONE_DOMAIN}<<<${ENDCOLOR}"
  gcloud dns record-sets transaction remove "$CTFD_INTERNAL_IP" \
    --name="$CTFD_INTERNAL_HOSTNAME.$INTERNAL_DNS_ZONE_DOMAIN" \
    --ttl="300" \
    --type="A" \
    --zone="$INTERNAL_DNS_ZONE_ID" \
    --quiet

  ## Remove Nginx A Record
  echo -e "\n${RED}>>>Deleting DNS A Record mapping ${NGINX_INTERNAL_IP} to ${NGINX_INTERNAL_HOSTNAME}.${INTERNAL_DNS_ZONE_DOMAIN}<<<${ENDCOLOR}"
  gcloud dns record-sets transaction remove "$NGINX_INTERNAL_IP" \
    --name="$NGINX_INTERNAL_HOSTNAME.$INTERNAL_DNS_ZONE_DOMAIN" \
    --ttl="300" \
    --type="A" \
    --zone="$INTERNAL_DNS_ZONE_ID" \
    --quiet

  ## Execute Transaction
  gcloud dns record-sets transaction execute \
    --zone="$INTERNAL_DNS_ZONE_ID" \
    --transaction-file="./transaction.yaml"

  # Delete internal IPs
  echo -e "\n${RED}>>>Deleting CTFd Host Private Static IP<<<${ENDCOLOR}"
  gcloud compute addresses delete "ctfd-internal-static-ip" --region "$GCP_REGION" --quiet

 echo -e "\n${RED}>>>Deleting Nginx Host Private Static IP<<<${ENDCOLOR}" 
  gcloud compute addresses delete "nginx-internal-static-ip" --region "$GCP_REGION" --quiet

  # Delete external IPs
  echo -e "\n${RED}>>>Deleting Nginx Host Public Static IP<<<${ENDCOLOR}"
  gcloud compute addresses delete "nginx-external-static-ip" --region "$GCP_REGION" --quiet
  
else
  echo "ERROR: First parameter must be one of up (build infrastructure) or down (tear down infrastructure)."
  echo "Usage: 3-build-scoreboard-component.sh [up|down]"
fi
