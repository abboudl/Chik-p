#! /usr/bin/env bash
set -e

for playbook in ./*-*.yml; do
  echo "****** Running: $playbook ******"
  ansible-playbook "$playbook" -i inventory.yml
done
