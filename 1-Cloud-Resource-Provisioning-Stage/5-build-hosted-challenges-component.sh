#!/usr/bin/env bash

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
ENDCOLOR="\e[0m"

# Check that the user has entered the correct number of parameters 
if [ "$#" -ne 1 ]; then
  echo "Usage: 5-build-hosted-challenges-component.sh [up|down]"
  exit 1
fi   

# Set the script mode to the first argument
SCRIPT_MODE="$1"

# Read configuration from global config file
source config.sh

# Build or tear down based on the provided script mode
if [ "$SCRIPT_MODE" = "up" ]; then

  # HAProxy Internal IP
  echo -e "\n${GREEN}>>>Reserving HAProxy Host Private Static IP ($HAPROXY_INTERNAL_IP)<<<${ENDCOLOR}"
  gcloud compute addresses create "haproxy-internal-static-ip" \
    --region "$GCP_REGION" \
    --subnet "$DMZ_SUBNET_ID" \
    --addresses "$HAPROXY_INTERNAL_IP"
			
  # HAProxy Static External IP
  echo -e "\n${GREEN}>>>Reserving HAProxy Host Public Static IP<<<${ENDCOLOR}"
  gcloud compute addresses create "haproxy-external-static-ip" \
    --region "$GCP_REGION"

  # Save HAProxy external public IP
  HAPROXY_PUBLIC_IP=$( \
    gcloud compute addresses list \
    --filter="NAME='haproxy-external-static-ip'" \
    --format="value(address)" | tr -d '\n' \
  )

  # Create DNS Records
  ## Start transaction
  echo -e "\n${GREEN}>>>Creating a DNS A Record mapping ${HAPROXY_INTERNAL_IP} to ${HAPROXY_INTERNAL_HOSTNAME}.${INTERNAL_DNS_ZONE_DOMAIN}<<<${ENDCOLOR}"
  gcloud dns record-sets transaction start \
    --zone="$INTERNAL_DNS_ZONE_ID"

  ## HAProxy A Record
  gcloud dns record-sets transaction add "$HAPROXY_INTERNAL_IP"\
    --name="$HAPROXY_INTERNAL_HOSTNAME.$INTERNAL_DNS_ZONE_DOMAIN" \
    --ttl="300" \
    --type="A" \
    --zone="$INTERNAL_DNS_ZONE_ID"

  ## Execute transaction
  gcloud dns record-sets transaction execute \
    --zone="$INTERNAL_DNS_ZONE_ID"

  # Create HAProxy VM
  echo -e "\n${GREEN}>>>Creating HAProxy Host (${HAPROXY_INTERNAL_HOSTNAME}.${INTERNAL_DNS_ZONE_DOMAIN})<<<${ENDCOLOR}"
  gcloud compute instances create "$HAPROXY_HOST_ID" \
    --hostname="$HAPROXY_INTERNAL_HOSTNAME.$INTERNAL_DNS_ZONE_DOMAIN" \
    --description="VM instance will host ISSessionsCTF HAProxy container acting as a proxy to TCP-Based Hosted Challenges." \
    --zone="$GCP_ZONE" \
    --machine-type="$HAPROXY_MACHINE_TYPE" \
    --subnet="$DMZ_SUBNET_ID" \
    --private-network-ip="$HAPROXY_INTERNAL_IP" \
    --address="$HAPROXY_PUBLIC_IP" \
    --network-tier="PREMIUM"\
    --maintenance-policy="MIGRATE" \
    --tags="haproxy-server" \
    --image="$HAPROXY_MACHINE_IMAGE" \
    --image-project="$HAPROXY_MACHINE_IMAGE_PROJECT" \
    --boot-disk-size="$HAPROXY_MACHINE_DISK_SIZE" \
    --boot-disk-type="$HAPROXY_MACHINE_DISK_TYPE" \
    --boot-disk-device-name="haproxy" \
    --reservation-affinity="any" \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --metadata-from-file=ssh-keys="$ANSIBLE_PUBLIC_KEY_PATH"
    

  # Set up Kubernetes hosted challenges cluster
  ## Create Cluster
  echo -e "\n${GREEN}>>>Creating Private ${HOSTED_CHALLENGES_CLUSTER_NODE_NUM}-Node Google Kubernetes Engine (GKE) Cluster for Hosted Challenges<<<${ENDCOLOR}"
  gcloud container clusters create "$HOSTED_CHALLENGES_CLUSTER_ID" \
    --zone "$GCP_ZONE" \
    --no-enable-basic-auth \
    --cluster-version "$HOSTED_CHALLENGES_CLUSTER_K8S_VERSION" \
    --release-channel "$HOSTED_CHALLENGES_CLUSTER_RELEASE_CHANNEL" \
    --machine-type "$HOSTED_CHALLENGES_CLUSTER_MACHINE_TYPE" \
    --image-type "$HOSTED_CHALLENGES_CLUSTER_IMAGE_TYPE" \
    --disk-type "$HOSTED_CHALLENGES_CLUSTER_DISK_TYPE" \
    --disk-size "$HOSTED_CHALLENGES_CLUSTER_DISK_SIZE" \
    --metadata disable-legacy-endpoints=true \
    --num-nodes "$HOSTED_CHALLENGES_CLUSTER_NODE_NUM" \
    --enable-stackdriver-kubernetes \
    --enable-private-nodes \
    --master-ipv4-cidr "10.10.100.0/28" \
    --enable-master-global-access \
    --enable-ip-alias \
    --network "projects/$GCP_PROJECT_ID/global/networks/$VPC_NETWORK" \
    --subnetwork "projects/$GCP_PROJECT_ID/regions/$GCP_REGION/subnetworks/$INTERNAL_HOSTED_CHALLENGES_SUBNET_ID" \
    --default-max-pods-per-node "110" \
    --enable-network-policy \
    --no-enable-master-authorized-networks \
    --addons HorizontalPodAutoscaling,HttpLoadBalancing \
    --enable-autoupgrade \
    --enable-autorepair \
    --max-surge-upgrade 1 \
    --max-unavailable-upgrade 0 \
    --enable-shielded-nodes \
    --tags "hosted-challenges-node"

  # Get authentication credentials to the cluster (configures kubectl command)
  echo -e "\n${GREEN}>>>Configuring kubectl Utility with Configuration Credentials to the Cluster<<<${ENDCOLOR}"
  gcloud container clusters get-credentials "$HOSTED_CHALLENGES_CLUSTER_ID" \
	  --zone="$GCP_ZONE"

  ## Promote current GCP service account to Kubernetes cluster admin
  echo -e "\n${GREEN}>>>Promoting Current Service Account to Kubernetes Cluster Admin<<<${ENDCOLOR}"
  kubectl create clusterrolebinding cluster-admin-binding \
    --clusterrole cluster-admin \
    --user $(gcloud config get-value account)

  ## Install ingress-nginx to route traffic to web-based stateful challenges
  echo -e "\n${GREEN}>>>Installing ingress-nginx Pod to Route Traffic to Stateful Web-Based Challenges<<<${ENDCOLOR}"
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.43.0/deploy/static/provider/cloud/deploy.yaml
  
  ## Create hosted-challenges namespace
  echo -e "\n${GREEN}>>>Creating a New Kubernetes Namespace for Hosted Challenges<<<${ENDCOLOR}"
  kubectl create namespace "$HOSTED_CHALLENGES_NAMESPACE"

  ## Delete validation webhook
  echo -e "\n${GREEN}>>>Deleting ingress-nginx Validation Webhook<<<${ENDCOLOR}"
  kubectl delete -A ValidatingWebhookConfiguration ingress-nginx-admission

  ## Create Cloud DNS records for Kubernetes nodes
  ### Start transaction
  gcloud dns record-sets transaction start \
    --zone="$INTERNAL_DNS_ZONE_ID"

  ### Make A records for each hosted challenge node
  i=0
  NODE_IP_LIST=$(kubectl get nodes -o=jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')
  for NODE_IP in $NODE_IP_LIST; do 
    NODE_FQDN="challenges-cluster-node-$i.$INTERNAL_DNS_ZONE_DOMAIN"
    echo -e "\n${GREEN}>>>Creating a DNS A Record mapping ${NODE_IP} to ${NODE_FQDN}<<<${ENDCOLOR}"
    gcloud dns record-sets transaction add "$NODE_IP"\
      --name="$NODE_FQDN" \
      --ttl="300" \
      --type="A" \
      --zone="$INTERNAL_DNS_ZONE_ID"
    i=$((i+1))
  done

  ### Execute transaction
  gcloud dns record-sets transaction execute \
    --zone="$INTERNAL_DNS_ZONE_ID"

  # Firewall Rules
  ## Create a firewall that allows traffic from anywhere to HaProxy public IP for ports 8080 (HAProxy Stats Panel)
  echo -e "\n${GREEN}>>>Creating Firewall Rule: Allow Connections From Anywhere (0.0.0.0/0) to HAProxy on Port 8080 (HAProxy Stats Panel)<<<${ENDCOLOR}"
  gcloud compute firewall-rules create "allow-http-to-haproxy-stats-panel" \
    --direction="INGRESS" \
    --priority="1000" \
    --network="$VPC_NETWORK" \
    --action="ALLOW" \
    --rules="tcp:8080" \
    --source-ranges="0.0.0.0/0" \
    --target-tags="haproxy-server"

  # Sleep for sixty seconds to allow all kubernetes resources to deploy
  sleep 60

  # Get ingress-nginx-controller public IP
  INGRESS_NGINX_CONTROLLER_PUBLIC_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')

  # Communicate Important Information
  echo -e "\n${YELLOW}>>>Next Steps: To allow access to TCP-Based challenges (netcat/SSH/etc.), add a DNS A record on your public domain's DNS portal"\
	  "mapping challenges.${PUBLIC_CTF_SUBDOMAIN}.${PUBLIC_DOMAIN} to HAProxy's Public IP: ${HAPROXY_PUBLIC_IP}<<<${ENDCOLOR}"

  echo -e "${YELLOW}This is required because players connect to the challenge Louai's Labyrinth, for example, by SSHing into"\
	  "challenges.${PUBLIC_CTF_SUBDOMAIN}.${PUBLIC_DOMAIN}:30500${ENDCOLOR}" 

elif [ "$SCRIPT_MODE" = "down" ]; then
  
  # Delete firewall rules
  echo -e "\n${RED}>>>Deleting Firewall Rule Allowing Connections From Anywhere (0.0.0.0/0) to HAProxy on Port 8080 (HAProxy Stats Panel)<<<${ENDCOLOR}"
  gcloud compute firewall-rules delete "allow-http-to-haproxy-stats-panel" --quiet	  
  
  # Delete HAProxy VM
  echo -e "\n${RED}>>>Deleting HAProxy Host (${HAPROXY_INTERNAL_HOSTNAME}.${INTERNAL_DNS_ZONE_DOMAIN})<<<${ENDCOLOR}"
  gcloud compute instances delete "$HAPROXY_HOST_ID" --zone="$GCP_ZONE" --quiet

  # Delete DNS records
  ## Start transaction
  gcloud dns record-sets transaction start \
    --zone="$INTERNAL_DNS_ZONE_ID"

  ## Delete HAProxy A record
  echo -e "\n${RED}>>>Deleting DNS A Record mapping ${HAPROXY_INTERNAL_IP} to ${HAPROXY_INTERNAL_HOSTNAME}.${INTERNAL_DNS_ZONE_DOMAIN}<<<${ENDCOLOR}"
  gcloud dns record-sets transaction remove "$HAPROXY_INTERNAL_IP"\
    --name="$HAPROXY_INTERNAL_HOSTNAME.$INTERNAL_DNS_ZONE_DOMAIN" \
    --ttl="300" \
    --type="A" \
    --zone="$INTERNAL_DNS_ZONE_ID" \
    --quiet

  ### Remove A records for each challenge node
  i=0
  NODE_IP_LIST=$(kubectl get nodes -o=jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')
  for NODE_IP in $NODE_IP_LIST; do
    NODE_FQDN="challenges-cluster-node-$i.$INTERNAL_DNS_ZONE_DOMAIN"
    echo -e "\n${RED}>>>Deleting DNS A Record mapping ${NODE_IP} to ${NODE_FQDN}<<<${ENDCOLOR}"
    gcloud dns record-sets transaction remove "$NODE_IP"\
      --name="$NODE_FQDN" \
      --ttl="300" \
      --type="A" \
      --zone="$INTERNAL_DNS_ZONE_ID"
    i=$((i+1))
  done

  ## Execute transaction
  gcloud dns record-sets transaction execute \
    --zone="$INTERNAL_DNS_ZONE_ID"

  # Delete Kubnernetes cluster
  echo -e "\n${RED}>>>Deleting Private ${HOSTED_CHALLENGES_CLUSTER_NODE_NUM}-Node Google Kubernetes Engine (GKE) Cluster for Hosted Challenges<<<${ENDCOLOR}"
  gcloud container clusters delete "$HOSTED_CHALLENGES_CLUSTER_ID" --zone="$GCP_ZONE" --quiet
  
  # Delete private and public IPs
  echo -e "\n${RED}>>>Deleting HAProxy Host Public Static IP<<<${ENDCOLOR}"
  gcloud compute addresses delete "haproxy-external-static-ip" --region="$GCP_REGION" --quiet
  echo -e "\n${RED}>>>Deleting HAProxy Host Private Static IP ($HAPROXY_INTERNAL_IP)<<<${ENDCOLOR}"
  gcloud compute addresses delete "haproxy-internal-static-ip" --region="$GCP_REGION" --quiet

else 
  echo "ERROR: First parameter must be one of up (build infrastructure) or down (tear down infrastructure)."
  echo "Usage: 5-build-hosted-challenges-component.sh [up|down]"
fi
 
 


