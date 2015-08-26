#!/bin/bash

# Usage info
show_help() {
cat << EOF
Help: 
  Assume your base is /etc/ansible, 
  BASE/ansible-docker/playbooks - have your playbooks
  BASE/target - have your docker hosts inventories
  BASE/target/target_name/* - extravars json, usally naming by domain name

  Create site:
    $0 linode_target/json_file playbook.yml

  Create site without prompt:
    $0 server1/test.com docker.yml --yes

  Example json:
    {"target":"neticrm-d7-docker","domain":"demo.neticrm.tw","port_www":"8003","port_db":"10003","repos":"netivism/docker-wheezy-php55","mount":"/var/www/drupal7","dbname":"demoneticrm","passwd":"abcabc","type":"neticrm"}
EOF
}

create_site() {
  VARFILE=$1
  echo "Creating site ..."
  ansible-playbook $BASE/ansible-docker/playbooks/$PLAYBOOK --extra-vars "$VARFILE" --tags=start
}

BASE=/etc/ansible
if [ "$#" -lt 2 ]; then
  show_help
  exit 0
else
  TARGET=$1
  PLAYBOOK=$2
fi

PROMPT=1
for VAR in "$@"; do
  if [ "$VAR" = "--yes" ]; then
    PROMPT=0
  fi
done

# ====================
if [ -f "$BASE/target/$TARGET" ]; then
  EXTRAVARS="@${BASE}/target/$TARGET"
  cat << EOF
Command will be execute:
  ansible-playbook docker.yml --extra-vars "$EXTRAVARS" --tags=start

EOF
  if [ $PROMPT -eq 0 ]; then
    create_site $EXTRAVARS $PLAYBOOK
  else
    read -p "Are you really want to create site? (y/n)" CHOICE 
    case "$CHOICE" in 
      y|Y ) 
        create_site $EXTRAVARS $PLAYBOOK
        ;;
      n|N ) 
        exit 1
        ;;
      * ) echo "invalid";;
    esac
  fi
else
  echo -e "\e[1;31m[File or target not found]\e[0m"
  show_help
  exit 0
fi

