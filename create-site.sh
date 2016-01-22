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
    {"target":"neticrm-d7-docker","domain":"demo.neticrm.tw","port_www":"8003","port_db":"10003","repos":"netivism/docker-wheezy-php55:fpm","mount":"/mnt/neticrm-7","dbname":"demoneticrm","passwd":"abcabc","type":"neticrm_fpm","init":"neticrm-7.sh"}
    {"target":"docker-test","domain":"t6.neticrm","port_www":"8002","port_db":"10002","repos":"netivism/docker-wheezy-php55:fpm","mount":"/mnt/neticrm-6","dbname":"t6neticrm","passwd":"123456","type":"neticrm_fpm","init":"neticrm-6.sh"}
EOF
}

create_site() {
  VARFILE=$1
  PLAYBOOK=$2
  echo "Creating site ..."
  ansible-playbook $PLAYBOOK/$DOCKER --extra-vars "$VARFILE" --tags=start
  ansible-playbook $PLAYBOOK/$MAIL --extra-vars "@$TARGET/vmail" --tags=stop
  ansible-playbook $PLAYBOOK/$MAIL --extra-vars "@$TARGET/vmail" --tags=start
}

BASE=/etc/ansible
if [ "$#" -lt 2 ]; then
  show_help
  exit 0
else
  IFS='/' read -r -a INPUT <<< "$1"
  LINODE="${INPUT[0]}"
  SITE="${INPUT[1]}"
  TARGET="$BASE/target/$LINODE"
  PLAYBOOK="$BASE/ansible-docker/playbooks"
  DOCKER=$2
  MAIL="mail.yml"
fi

PROMPT=1
for VAR in "$@"; do
  if [ "$VAR" = "--yes" ]; then
    PROMPT=0
  fi
done

# ====================
if [ -f "$TARGET/$SITE" ]; then
  EXTRAVARS="@$TARGET/$SITE"
  cat << EOF
Command will be execute:
  ansible-playbook docker.yml --extra-vars "$EXTRAVARS" --tags=start
  ansible-playbook mail.yml --extra-vars "@$TARGET/vmail" --tags=stop
  ansible-playbook mail.yml --extra-vars "@$TARGET/vmail" --tags=start

EOF
  if [ $PROMPT -eq 0 ]; then
    create_site $EXTRAVARS $PLAYBOOK/$DOCKER
  else
    read -p "Are you really want to create site? (y/n)" CHOICE 
    case "$CHOICE" in 
      y|Y ) 
        create_site $EXTRAVARS $PLAYBOOK/$DOCKER
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

