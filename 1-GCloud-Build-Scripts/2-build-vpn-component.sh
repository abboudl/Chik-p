#!/usr/bin/env bash

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
ENDCOLOR="\e[0m"

# Check that the user has entered the correct number of parameters
if [ "$#" -ne 1 ]; then
  echo "Usage: 2-build-vpn-component.sh [up|down]"
  exit 1
fi

# Set the script mode to the first argument
SCRIPT_MODE="$1"

# Read configuration from global config file
source config.sh

# Build or tear down based on the provided script mode
if [ "$SCRIPT_MODE" = "up" ]; then

  # Wireguard Host Static External Public IP
  echo -e "\n${GREEN}>>>Reserving Wireguard Public Static IP<<<${ENDCOLOR}"
  gcloud compute addresses create "wireguard-external-static-ip" \
	  --region "$GCP_REGION"

  # Save Wireguard External Public IP
  WG_PUBLIC_IP=$( \
          gcloud compute addresses list \
	  --filter="NAME='wireguard-external-static-ip'" \
	  --format="value(address)" | tr -d '\n' \
  	  )
  
  # Wireguard Host Internal IP
  echo -e "\n${GREEN}>>>Reserving Wireguard Private Static IP (${WG_INTERNAL_IP})<<<${ENDCOLOR}"
  gcloud compute addresses create "wireguard-internal-static-ip" \
	  --region "$GCP_REGION" --subnet "$DMZ_SUBNET_ID" \
	  --addresses "$WG_INTERNAL_IP"

  # Create DNS Records
  ## Start Transaction
  echo -e "\n${GREEN}>>>Creating a DNS A Record mapping ${WG_INTERNAL_IP} to ${WG_INTERNAL_HOSTNAME}.${INTERNAL_DNS_ZONE_DOMAIN}<<<${ENDCOLOR}"
  gcloud dns record-sets transaction start \
	  --zone="$INTERNAL_DNS_ZONE_ID" \
          --transaction-file="./transaction.yaml"

  ## Wireguard A Record
  gcloud dns record-sets transaction add "$WG_INTERNAL_IP" \
	  --name="$WG_INTERNAL_HOSTNAME.$INTERNAL_DNS_ZONE_DOMAIN" \
	  --ttl="300" \
	  --type="A" \
	  --zone="$INTERNAL_DNS_ZONE_ID"

  ## Execute Transaction
  gcloud dns record-sets transaction execute \
	  --zone="$INTERNAL_DNS_ZONE_ID" \
	  --transaction-file="./transaction.yaml"  

  # Create Wireguard Host
  echo -e "\n${GREEN}>>>Creating Wireguard Host (${WG_INTERNAL_HOSTNAME}.${INTERNAL_DNS_ZONE_DOMAIN})<<<${ENDCOLOR}"
  gcloud compute instances create "$WG_HOST_ID" \
          --hostname="$WG_INTERNAL_HOSTNAME.$INTERNAL_DNS_ZONE_DOMAIN" \
          --description="VM instance will host Wireguard Gateway." \
          --zone="$GCP_ZONE" \
          --machine-type="$WG_MACHINE_TYPE" \
          --subnet="$DMZ_SUBNET_ID" \
          --private-network-ip="$WG_INTERNAL_IP" \
          --address="$WG_PUBLIC_IP" \
          --network-tier="PREMIUM" \
          --maintenance-policy="MIGRATE" \
          --tags="wireguard-server" \
          --image="$WG_MACHINE_IMAGE" \
          --image-project="$WG_MACHINE_IMAGE_PROJECT" \
          --boot-disk-size="$WG_MACHINE_DISK_SIZE" \
          --boot-disk-type="$WG_MACHINE_DISK_TYPE" \
          --boot-disk-device-name="wireguard" \
          --reservation-affinity="any" \
          --no-shielded-secure-boot \
          --shielded-vtpm \
          --shielded-integrity-monitoring \
	  --can-ip-forward \
          --metadata-from-file=ssh-keys="$ANSIBLE_PUBLIC_KEY_PATH"

  # Firewall: Allow Access to VPN
  echo -e "\n${GREEN}>>>Creating Firewall Rule: Allow Any (0.0.0.0/0) to VPN Host on ${WG_PROTOCOL}-${WG_PORT}<<<${ENDCOLOR}"
  gcloud compute firewall-rules create "allow-vpn-$WG_PROTOCOL-$WG_PORT" \
	  --direction="INGRESS" \
	  --priority="1000" \
          --network="$VPC_NETWORK" \
          --action="ALLOW" \
	  --rules="$WG_PROTOCOL:$WG_PORT" \
	  --source-ranges="0.0.0.0/0" \
	  --target-tags="wireguard-server"

  # Set up GCP Static Route Back to VPN Gateway
  echo -e "\n${GREEN}>>>Setting Up Static Route from VPC Network to Wireguard Client Subnet<<<${ENDCOLOR}"
  gcloud compute routes create "vpn-route-to-virtual-client-network" \
	  --network="$VPC_NETWORK" \
	  --priority=1000 \
	  --destination-range="$WG_CLIENT_SUBNET" \
	  --next-hop-instance="$WG_HOST_ID" \
	  --next-hop-instance-zone="$GCP_ZONE"

  # Communicate Important Information
  echo -e "\n${YELLOW}>>>Next Step: Add a DNS A record on your public domain's DNS portal"\
	  "mapping vpn.${PUBLIC_CTF_SUBDOMAIN}.${PUBLIC_DOMAIN} to the Wireguard's Public IP: ${WG_PUBLIC_IP}<<<${ENDCOLOR}"

elif [ "$SCRIPT_MODE" = "down" ]; then

  # Delete Static Route
  echo -e "\n${RED}>>>Deleting Static Route from VPC Network to Wireguard Client Subnet<<<${ENDCOLOR}"
  gcloud compute routes delete "vpn-route-to-virtual-client-network" --quiet

  # Delete Firewall Rules
  echo -e "\n${RED}>>>Deleting Firewall Rule Allowing Access from Anywhere to VPN Host on $WG_PROTOCOL-$WG_PORT<<<${ENDCOLOR}"
  gcloud compute firewall-rules delete "allow-vpn-$WG_PROTOCOL-$WG_PORT" --quiet

  # Delete Hosts
  echo -e "\n${RED}>>>Deleting Wireguard Host (${WG_INTERNAL_HOSTNAME}.${INTERNAL_DNS_ZONE_DOMAIN})<<<${ENDCOLOR}"
  gcloud compute instances delete "$WG_HOST_ID" --quiet --zone="$GCP_ZONE"

  # Delete DNS Record
  ## Start Transaction
  echo -e "\n${RED}>>>Deleting DNS A Record mapping ${WG_INTERNAL_IP} to ${WG_INTERNAL_HOSTNAME}.${INTERNAL_DNS_ZONE_DOMAIN}<<<${ENDCOLOR}"
  gcloud dns record-sets transaction start \
    --zone="$INTERNAL_DNS_ZONE_ID" \
    --transaction-file="./transaction.yaml"

  ## Remove WG A Record
  gcloud dns record-sets transaction remove "$WG_INTERNAL_IP" \
    --name="$WG_INTERNAL_HOSTNAME.$INTERNAL_DNS_ZONE_DOMAIN" \
    --ttl="300" \
    --type="A" \
    --zone="$INTERNAL_DNS_ZONE_ID" \
    --quiet

  ## Execute Transaction
  gcloud dns record-sets transaction execute \
    --zone="$INTERNAL_DNS_ZONE_ID" \
    --transaction-file="./transaction.yaml"

  # Delete internal IPs
  echo -e "\n${RED}>>>Deleting Wireguard Private Static IP (${WG_INTERNAL_IP})<<<${ENDCOLOR}"
  gcloud compute addresses delete "wireguard-internal-static-ip" \
	  --region "$GCP_REGION" \
	  --quiet

  # Delete external IPs
  echo -e "\n${RED}>>>Deleting Wireguard Public Static IP<<<${ENDCOLOR}"
  gcloud compute addresses delete "wireguard-external-static-ip" \
    --region "$GCP_REGION" --quiet

else
  echo "ERROR: First parameter must be one of up (build infrastructure) or down (tear down infrastructure)."
  echo "Usage: 2-build-vpn-component.sh [up|down]"
fi




