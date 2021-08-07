#!/usr/bin/env bash

creds=("ctf_user_pass:ctf"
    "ctf_elastic_user_bootstrap_pass:elastic"
    "ctf_elastic_user_permanent_pass:elastic"
    "ctf_logstash_system_user_pass:logstash_system"
    "ctf_kibana_system_user_pass:kibana_system"
    "ctf_logstash_internal_user_pass:logstash_internal"
    "ctf_ctfd_secret_key:ctf_ctfd_secret_key"
    "ctf_mysql_account:ctf_mysql_account"
    "ctf_mysql_root_pass:root"
    "ctf_haproxy_stats_panel_account:ctf_haproxy_stats_panel_account"
    )

for cred in ${creds[@]}; do
    id=($(echo $cred | tr ':' '\n'))
    ((lpass show ${id[0]} &> /dev/null) && echo "${id[0]} already exists") || 
    (lpass generate --username=${id[1]} chik-p/${id[0]} 16 &> /dev/null && 
    echo "${id[0]} password generated")
done