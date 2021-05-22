#!/usr/bin/env bash

# Read in .env secrets file
set -a; source .env; set +a

# ELK Host Internal FQDN
ES_HOST=elk.int.ctf.issessions.ca

# Set the password of the kibana_system user using the Elasticsearch security API
curl -k -XPOST -u elastic:"${BOOTSTRAP_ELASTIC_PASSWORD}" \
  -H "Content-Type: application/json" \
  https://"$ES_HOST":9200/_security/user/kibana_system/_password -d @- << EOF
  {
    "password": "${KIBANA_SYSTEM_USER_PASS}"
  }
EOF

# Ensure that the kibana_system user is enabled
curl -k -XPOST -u elastic:"${BOOTSTRAP_ELASTIC_PASSWORD}" \
  -H "Content-Type: application/json" \
  https://"$ES_HOST":9200/_security/user/kibana_system/_enable

# Set the password of the logstash_system user using the Elasticsearch security API
curl -k -XPOST -u elastic:"${BOOTSTRAP_ELASTIC_PASSWORD}" \
  -H "Content-Type: application/json" \
  https://"$ES_HOST":9200/_security/user/logstash_system/_password -d @- << EOF
  {
    "password": "${LOGSTASH_SYSTEM_USER_PASS}"
  }
EOF

# Ensure that the logstash_system user is enabled
curl -k -XPOST -u elastic:"${BOOTSTRAP_ELASTIC_PASSWORD}" \
  -H "Content-Type: application/json" \
  https://"$ES_HOST":9200/_security/user/logstash_system/_enable

# Create the logstash_writer role and give it the ability to manage CTF indices 
# (read, write, create, and delete)
curl -k -XPOST -u elastic:"${BOOTSTRAP_ELASTIC_PASSWORD}" -H "Content-Type: application/json" \
  https://"$ES_HOST":9200/_xpack/security/role/logstash_writer -d @- << EOF 
  {
    "cluster": ["manage_index_templates", "monitor", "manage_ilm"], 
    "indices": [
      {
        "names": [ "ctf-*" ], 
        "privileges": ["write","create","delete","create_index","manage","manage_ilm"]  
      }
    ]  
  }
EOF

# Create the logstash_internal user and assign it the logstash_writer role
curl -k -XPOST -u elastic:"${BOOTSTRAP_ELASTIC_PASSWORD}" \
  -H "Content-Type: application/json" \
  https://"$ES_HOST":9200/_xpack/security/user/logstash_internal -d @- << EOF
  {
    "password" : "${LOGSTASH_INTERNAL_USER_PASS}",
    "roles" : [ "logstash_writer"],
    "full_name" : "Internal Logstash Writer"
  }
EOF

# Finally, change the boostrap elastic user's password to a permanent password 
curl -k -XPOST -u elastic:"${BOOTSTRAP_ELASTIC_PASSWORD}" \
  -H "Content-Type: application/json" \
  https://"$ES_HOST":9200/_security/user/elastic/_password -d @- << EOF
  {
    "password": "${PERMANENT_ELASTIC_PASSWORD}"
  }
EOF

