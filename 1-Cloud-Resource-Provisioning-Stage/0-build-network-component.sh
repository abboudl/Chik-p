#!/usr/bin/env bash

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
ENDCOLOR="\e[0m"

# Check that the user has entered the correct number of parameters
if [ "$#" -ne 1 ]; then
  echo "Usage: 1-build-network-component.sh [up|down]"
  exit 1
fi

# Set the script mode to the first argument
SCRIPT_MODE="$1"

# Read configuration from global config file
source config.sh

# Global vars
NAT_ROUTER_ID="nat-router"

# Build or tear down based on the provided script mode
if [ "$SCRIPT_MODE" = "up" ]; then

  # Create Virtual Private Cloud (VPC)
  echo -e "\n${GREEN}>>>Creating Virtual Private Cloud<<<${ENDCOLOR}"
  gcloud compute networks create "$VPC_NETWORK" \
	  --subnet-mode="custom" \
	  --bgp-routing-mode="regional" \
	  --mtu="1460"

  # Create Subnets
  echo -e "\n${GREEN}>>>Creating DMZ Subnet<<<${ENDCOLOR}"
  gcloud compute networks subnets create "$DMZ_SUBNET_ID" \
	  --network="$VPC_NETWORK" --range="$DMZ_SUBNET_IP_RANGE" \
	  --region="$GCP_REGION"

  echo -e "\n${GREEN}>>>Creating Internal Subnet<<<${ENDCOLOR}"
  gcloud compute networks subnets create "$INTERNAL_SUBNET_ID" \
	  --network="$VPC_NETWORK" \
	  --range="$INTERNAL_SUBNET_IP_RANGE" \
	  --region="$GCP_REGION"

  echo -e "\n${GREEN}>>>Creating Hosted Challenges Cluster Subnet<<<${ENDCOLOR}"
  gcloud compute networks subnets create "$INTERNAL_HOSTED_CHALLENGES_SUBNET_ID" \
	  --network="$VPC_NETWORK" \
	  --range="$INTERNAL_HOSTED_CHALLENGES_SUBNET_IP_RANGE" \
	  --region="$GCP_REGION"

  # Create a Cloud Router and setup NAT to allow private VMs to reach internet
  echo -e "\n${GREEN}>>>Creating Cloud Router and Setting up NAT to Allow Private VMs to Reach Internet<<<${ENDCOLOR}"
  gcloud compute routers create "$NAT_ROUTER_ID" \
          --network "$VPC_NETWORK" \
          --region "$GCP_REGION"

  gcloud compute routers nats create "nat-config" \
          --router-region "$GCP_REGION" \
          --router "$NAT_ROUTER_ID" \
          --nat-all-subnet-ip-ranges \
          --auto-allocate-nat-external-ips

  # Configure Basic Firewall Rules (ICMP and SSH)
  echo -e "\n${GREEN}>>>Configuring Firewall Rules<<<${ENDCOLOR}"
  gcloud compute firewall-rules create "allow-ssh" \
	  --network "$VPC_NETWORK" \
	  --direction "ingress" \
	  --action "allow" \
	  --rules "tcp:22" \
	  --source-ranges "0.0.0.0/0" \
	  --priority "65534"

  gcloud compute firewall-rules create "allow-icmp" \
	  --network "$VPC_NETWORK" \
	  --direction "ingress" \
	  --action "allow" \
	  --rules "icmp" \
	  --source-ranges "0.0.0.0/0" \
	  --priority "65534"

  # Delete Default Network
  echo -e "\n${GREEN}>>>Deleted "Default" GCP Network and Default GCP Firewall Rules<<<${ENDCOLOR}"
  gcloud compute firewall-rules delete "default-allow-ssh" --quiet 2> /dev/null
  gcloud compute firewall-rules delete "default-allow-icmp" --quiet 2> /dev/null
  gcloud compute firewall-rules delete "default-allow-rdp" --quiet 2> /dev/null
  gcloud compute firewall-rules delete "default-allow-internal" --quiet 2> /dev/null
  gcloud compute networks delete "default" --quiet 2> /dev/null

  # Create Managed Cloud DNS Zone
  echo -e "\n${GREEN}>>>Creating Managed Cloud DNS Zone<<<${ENDCOLOR}"
  gcloud dns managed-zones create "$INTERNAL_DNS_ZONE_ID" \
	  --description="Private DNS Zone for ISSessionsCTF Infrastructure." \
	  --dns-name="$INTERNAL_DNS_ZONE_DOMAIN" \
	  --networks="$VPC_NETWORK" \
	  --visibility=private

  # Create Inbound Forwarding Policy to Allow VPN Clients (On-Prem) to Query GCP Private DNS Zones
  echo -e "\n${GREEN}>>>Creating Inbound Forwarding Policy to Allow VPN Clients (On-Prem) to Query GCP Private DNS Zones<<<${ENDCOLOR}"
  gcloud dns policies create "allow-on-prem-to-query-gcp-dns-policy" \
	  --description="This policy allows VPN clients to query the private DNS zone of the GCP ISSessionsCTF environment." \
	  --networks="$VPC_NETWORK" \
	  --enable-inbound-forwarding

elif [ "$SCRIPT_MODE" = "down" ]; then

  # Delete Managed Cloud DNS Zone
  ## Delete All Records
  echo -e "\n${RED}>>>Deleting Managed Cloud DNS Zone<<<${ENDCOLOR}"
  touch record-file
  gcloud dns record-sets import -z "$INTERNAL_DNS_ZONE_ID" \
	     --delete-all-existing record-file
  rm record-file

  ## Delete Zone
  gcloud dns managed-zones delete "$INTERNAL_DNS_ZONE_ID" --quiet

  # Delete Firewall Rules
  echo -e "\n${RED}>>>Deleting Firewall Rules<<<${ENDCOLOR}"
  gcloud compute firewall-rules delete "allow-ssh" --quiet
  gcloud compute firewall-rules delete "allow-icmp" --quiet

  # Delete Cloud Router and Cloud NAT configuration
  echo -e "\n${RED}>>>Deleting Cloud Router and Cloud NAT Configuration<<<${ENDCOLOR}"
  gcloud compute routers nats delete "nat-config" --router="$NAT_ROUTER_ID" --region="$GCP_REGION" --quiet
  gcloud compute routers delete "$NAT_ROUTER_ID" --region="$GCP_REGION" --quiet

  # Delete Subnets
  echo -e "\n${RED}>>>Deleting DMZ Subnet<<<${ENDCOLOR}"
  gcloud compute networks subnets delete "$DMZ_SUBNET_ID" --region="$GCP_REGION" --quiet
  echo -e "\n${RED}>>>Deleting Internal CTFd Subnet<<<${ENDCOLOR}"
  gcloud compute networks subnets delete "$INTERNAL_SUBNET_ID" --region="$GCP_REGION" --quiet
  echo -e "\n${RED}>>>Deleting Hosted Challenges Cluster Subnet<<<${ENDCOLOR}" 
  gcloud compute networks subnets delete "$INTERNAL_HOSTED_CHALLENGES_SUBNET_ID" --region="$GCP_REGION" --quiet

  # Delete VPC
  echo -e "\n${RED}>>>Deleting Virtual Private Network(VPC)<<<${ENDCOLOR}"
  gcloud compute networks delete "$VPC_NETWORK" --quiet
 
  # Delete DNS Policy
  sleep 30s
  echo -e "\n${RED}>>>Deleting DNS Policies<<<${ENDCOLOR}"  
  gcloud dns policies delete "allow-on-prem-to-query-gcp-dns-policy" --quiet
  echo -e "Note: There is a bug where sometimes the DNS server does not delete properly because it thinks the VPC still exists.\nIf this occurs, you can delete the DNS server policy  manually by going to: Cloud DNS > DNS Server Policies in the GCP Cloud Console."

else
  echo "ERROR: First parameter must be one of up (build infrastructure) or down (tear down infrastructure)."
  echo "Usage: 1-build-network-component.sh [up|down]"
fi




