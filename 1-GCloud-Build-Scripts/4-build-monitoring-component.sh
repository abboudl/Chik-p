#!/usr/bin/env bash

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
ENDCOLOR="\e[0m"

# Check that the user has entered the correct number of parameters
if [ "$#" -ne 1 ]; then
  echo "Usage: 4-build-monitoring-component.sh [up|down]"
  exit 1
fi

# Set the script mode to the first argument
SCRIPT_MODE="$1"

# Read configuration from global config file
source config.sh 

# Build or tear down based on the provided script mode
if [ "$SCRIPT_MODE" = "up" ]; then

  # Reserve Static Internal IP Addresses
  ## ELK Host Internal IP
  echo -e "\n${GREEN}>>>Reserving ELK Host Private Static IP ($ELK_INTERNAL_IP)<<<${ENDCOLOR}"
  gcloud compute addresses create "elk-internal-static-ip" \
    --region "$GCP_REGION" --subnet "$INTERNAL_SUBNET_ID" \
    --addresses "$ELK_INTERNAL_IP"

  # Create DNS Records
  ## Start Transaction
  echo -e "\n${GREEN}>>>Creating a DNS A Record mapping ${ELK_INTERNAL_IP} to ${ELK_INTERNAL_HOSTNAME}.${INTERNAL_DNS_ZONE_DOMAIN}<<<${ENDCOLOR}"
  gcloud dns record-sets transaction start \
     --zone="$INTERNAL_DNS_ZONE_ID" \
     --transaction-file="./transaction.yaml"

  gcloud dns record-sets transaction add "$ELK_INTERNAL_IP" \
     --name="$ELK_INTERNAL_HOSTNAME.$INTERNAL_DNS_ZONE_DOMAIN" \
     --ttl="300" \
     --type="A" \
     --zone="$INTERNAL_DNS_ZONE_ID"

  ## Execute Transaction
  gcloud dns record-sets transaction execute \
     --zone="$INTERNAL_DNS_ZONE_ID" \
     --transaction-file="./transaction.yaml"
 
  # Create VMs
  ## ELK Host
  echo -e "\n${GREEN}>>>Creating ELK Host (${ELK_INTERNAL_HOSTNAME}.${INTERNAL_DNS_ZONE_DOMAIN})<<<${ENDCOLOR}" 
  gcloud compute instances create "$ELK_HOST_ID" \
    --hostname="$ELK_INTERNAL_HOSTNAME.$INTERNAL_DNS_ZONE_DOMAIN" \
    --description="VM instance will host an ELK stack to monitor and collect statistics for ISSessiosCTF." \
    --zone="$GCP_ZONE" \
    --machine-type="$ELK_MACHINE_TYPE" \
    --subnet="$INTERNAL_SUBNET_ID" \
    --private-network-ip="$ELK_INTERNAL_IP" \
    --no-address \
    --maintenance-policy="MIGRATE" \
    --tags="elk-server" \
    --image="$ELK_MACHINE_IMAGE" \
    --image-project="$ELK_MACHINE_IMAGE_PROJECT" \
    --boot-disk-size="$ELK_MACHINE_DISK_SIZE" \
    --boot-disk-type="$ELK_MACHINE_DISK_TYPE" \
    --boot-disk-device-name="elk" \
    --reservation-affinity="any" \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --metadata-from-file=ssh-keys="$ANSIBLE_PUBLIC_KEY_PATH"

  # Firewall 
  ## Allow communication from CTFD Host to ELK Host (Logstash Beats Port 5044)
  echo -e "\n${GREEN}>>>Creating Firewall Rule: Allow Connections From CTFd Host to ELK Host on port 5044 (Submission Logs: Filebeat Agent -> Logstash)<<<${ENDCOLOR}"
  gcloud compute firewall-rules create "allow-ctfd-to-elk-logstash-$LOGSTASH_BEATS_PORT" \
    --direction="INGRESS" \
    --priority="1000" \
    --network="$VPC_NETWORK" \
    --action="ALLOW" \
    --rules="tcp:$LOGSTASH_BEATS_PORT" \
    --source-tags="ctfd-server" \
    --target-tags="elk-server"

  ## Allow communication from Nginx Host to ELK Host (Logstash Beats Port 5044)
  echo -e "\n${GREEN}>>>Creating Firewall Rule: Allow Connections From Nginx Host to ELK Host on port 5044 (Web Server Logs: Filebeat Agent -> Logstash)<<<${ENDCOLOR}"
  gcloud compute firewall-rules create "allow-nginx-to-elk-logstash-$LOGSTASH_BEATS_PORT" \
    --direction="INGRESS" \
    --priority="1000" \
    --network="$VPC_NETWORK" \
    --action="ALLOW" \
    --rules="tcp:$LOGSTASH_BEATS_PORT" \
    --source-tags="nginx-server" \
    --target-tags="elk-server"

  ## Allow Communication from VPN to ELK Host (Kibana Port 5601)
  echo -e "\n${GREEN}>>>Creating Firewall Rule: Allow Connections From VPN Host to ELK Host on port 5601 (Kibana Dashboard Access)<<<${ENDCOLOR}"
  gcloud compute firewall-rules create "allow-vpn-to-elk-kibana-$KIBANA_PORT" \
    --direction="INGRESS" \
    --priority="1000" \
    --network="$VPC_NETWORK" \
    --action="ALLOW" \
    --rules="tcp:$KIBANA_PORT" \
    --source-tags="wireguard-server" \
    --target-tags="elk-server"

  ## Allow Communication from VPN to ELK Host (Elasticsearch Port 9200) for API calls
  echo -e "\n${GREEN}>>>Creating Firewall Rule: Allow Connections From VPN Host to ELK Host on port 9200 (Elasticsearch API Access)<<<${ENDCOLOR}"
  gcloud compute firewall-rules create "allow-vpn-to-elk-es-$ES_PORT" \
    --direction="INGRESS" \
    --priority="1000" \
    --network="$VPC_NETWORK" \
    --action="ALLOW" \
    --rules="tcp:$ES_PORT" \
    --source-tags="wireguard-server" \
    --target-tags="elk-server"

elif [ "$SCRIPT_MODE" = "down" ]; then

  # Delete Firewall Rules
  echo -e "\n${RED}>>>Deleting Firewall Rule Allowing Connections From VPN Host to ELK Host on port 9200 (Elasticsearch API Access)<<<${ENDCOLOR}"
  gcloud compute firewall-rules delete "allow-vpn-to-elk-es-$ES_PORT" --quiet

  echo -e "\n${RED}>>>Deleting Firewall Rule Allowing Connections From CTFd Host to ELK Host on port 5044 (Filebeat Agent Logs)<<<${ENDCOLOR}"
  gcloud compute firewall-rules delete "allow-ctfd-to-elk-logstash-$LOGSTASH_BEATS_PORT" --quiet

  echo -e "\n${RED}>>>Deleting Firewall Rule Allowing Connections From Nginx Host to ELK Host on port 5044 (Filebeat Agent Logs)<<<${ENDCOLOR}"
  gcloud compute firewall-rules delete "allow-nginx-to-elk-logstash-$LOGSTASH_BEATS_PORT" --quiet

  echo -e "\n${RED}>>>Deleting Firewall Rule Allowing Connections From VPN Host to ELK Host on port 5601 (Kibana Dashboard Access)<<<${ENDCOLOR}"
  gcloud compute firewall-rules delete "allow-vpn-to-elk-kibana-$KIBANA_PORT" --quiet
  
  # Delete Hosts
  echo -e "\n${RED}>>>Deleting ELK Host (${ELK_INTERNAL_HOSTNAME}.${INTERNAL_DNS_ZONE_DOMAIN})<<<${ENDCOLOR}"
  gcloud compute instances delete "$ELK_HOST_ID" --quiet --zone="$GCP_ZONE"

  # Delete DNS Records
  ## Start Transaction
  echo -e "\n${RED}>>>Deleting DNS A Record mapping ${ELK_INTERNAL_IP} to ${ELK_INTERNAL_HOSTNAME}.${INTERNAL_DNS_ZONE_DOMAIN}<<<${ENDCOLOR}"
  gcloud dns record-sets transaction start \
    --zone="$INTERNAL_DNS_ZONE_ID" \
    --transaction-file="./transaction.yaml"

  ## Remove ELK A Record
  gcloud dns record-sets transaction remove "$ELK_INTERNAL_IP" \
    --name="$ELK_INTERNAL_HOSTNAME.$INTERNAL_DNS_ZONE_DOMAIN" \
    --ttl="300" \
    --type="A" \
    --zone="$INTERNAL_DNS_ZONE_ID" \
    --quiet

  ## Execute Transaction
  gcloud dns record-sets transaction execute \
    --zone="$INTERNAL_DNS_ZONE_ID" \
    --transaction-file="./transaction.yaml"

  # Delete internal IPs
  echo -e "\n${RED}>>>Deleting ELK Host Private Static IP ($ELK_INTERNAL_IP)<<<${ENDCOLOR}"
  gcloud compute addresses delete "elk-internal-static-ip" --region "$GCP_REGION" --quiet
  
else
  echo "ERROR: First parameter must be one of up (build infrastructure) or down (tear down infrastructure)."
  echo "Usage: 4-build-monitoring-component.sh [up|down]"
fi
