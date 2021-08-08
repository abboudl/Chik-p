# Lastpass Secrets Catalog

For the infrastructure build process to succeed, Lastpass must be seeded with the following credentials.
1. Create an entry for each of these secrets in your CTF Lastpass password vault
2. Place the **LastPass ID** column in the **Name** field.
3. Place the **Username** column in the **Username** field.
4. Generate a secret that follows the specification given in the **Secret Type** column and place it in the **Password** field

## Local Accounts
| LastPass ID   | Secret Type | Username | Description | 
|---------------|-------------|----------|-------------|
| ctf_user_pass | 16+ Character Password    | ctf      | Password of the `ctf` user. The `ctf` user exists on all hosts in the CTF environment. The CTF infrastructure administrator uses an SSH key to login as the `ctf` user. This password is used to sudo to root if needed.|            |

## ELK Accounts
| LastPass ID                     | Secret Type | Username         | Description | 
|---------------------------------|-------------|------------------|-------------|
| ctf_elastic_user_bootstrap_pass | 16+ Character Password    | elastic          | The elastic user is the equivalent of root in Elasticsearch. It has two passwords. The bootstrap password is used to start the cluster and set the passwords of kibana_system and logstash_system. This password is then changed when the ELK cluster bootstrap process is completed and the logstash_system and kibana_system passwords have been set to ctf_elastic_user_permanent_pass |
| ctf_elastic_user_permanent_pass | 16+ Character Password    | elastic          | The elastic user is the equivalent of root in Elasticsearch. It has two passwords. The bootstrap password is used to start the cluster and set the passwords of kibana_system and logstash_system. This password is then changed when the ELK cluster bootstrap process is completed and the logstash_system and kibana_system passwords have been set to ctf_elastic_user_permanent_pass |
| ctf_logstash_system_user_pass   | 16+ Character Password    | logstash_system  | The logstash_system user is used for shipping logstash monitoring data to a secure Elasticsearch cluster (i.e. to monitor the logstash system)|                                                                                                  
| ctf_kibana_system_user_pass     | 16+ Character Password    | kibana_system    | The kibana_system user is used for shipping kibana monitoring data to a secure Elasticsearch cluster (i.e. to monitor the kibana system)|
| ctf_logstash_internal_user_pass | 16+ Character Password    | logstash_internal| The logstash_internal has the logstash_writr role and is responsible for writing data parsed by logstash to elasticsearch (like processed Nginx and CTFd logs)|

## CTFd Accounts
| LastPass ID                     | Secret Type              | Username            | Description                                                                                              | 
|---------------------------------|--------------------------|---------------------|----------------------------------------------------------------------------------------------------------|
| ctf_ctfd_secret_key             | 64-Character Secret Key  | ctf_ctfd_secret_key | Used by the CTFd Flask application to sign session cookies for protection against cookie data tampering. |
| ctf_mysql_account               | 16+ Character Password                 | *pick-a-username*   | Username and password are set by the CTF Infrastructure Administrator. This account is used by CTFd's object relational mapper (ORM) to populate the ctfd database. It can also be used by the CTF Administrator to manually manage the Mariadb MySQL database if needed.|
| ctf_mysql_root_pass             | 16+ Character Password                 | root                | Root password to the MySQL DBMS. Username is "root".                                                     |

## Nginx Accounts
None.

## HAProxy
| LastPass ID                     | Secret Type              | Username            | Description                                                                                              | 
|---------------------------------|--------------------------|---------------------|----------------------------------------------------------------------------------------------------------|
| ctf_haproxy_stats_panel_account | 16+ Character Password                 | *pick-a-username*   | Username and password are set by the CTF Infrastructure Administrator. Provides access to a dashboard exposed on port 8080 for monitoring hosted challenges (bruteforcing, excessive # of connections, etc.) |                                                                                                         |

## Cloudflare (If Applicable)
| Account/Credential           | Secret Type | LastPass Credential Name        | Description                                                                          |
| -----------------------------|-------------|---------------------------------|--------------------------------------------------------------------------------------|
| ctf_cloudflare_dns_api_token | API Token   | cloudflare dns api token        | If your domain is registered with Cloudflare, this is the API token certbot uses to request a letsencrypt certificate using the DNS challenge. Token must have DNS:Edit permissions. It can be generated through the Cloudflare portal.|









