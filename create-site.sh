#!/bin/bash

PROMPT=1
WELCOME=0
BASE=/etc/ansible
LINODE=""
set -e

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

  Create site without prompt and send welcome letter:
    $0 server1/test.com docker.yml --yes --welcome-letter

  Example json:
    {"target":"neticrm-d7-docker","domain":"demo.neticrm.tw","port_www":"8003","port_db":"10003","repos":"netivism/docker-wheezy-php55:fpm","mount":"/mnt/neticrm-7","dbname":"demoneticrm","passwd":"abcabc","type":"neticrm_fpm","init":"neticrm-7.sh"}
    {"target":"docker-test","domain":"t6.neticrm","port_www":"8002","port_db":"10002","repos":"netivism/docker-wheezy-php55:fpm","mount":"/mnt/neticrm-6","dbname":"t6neticrm","passwd":"123456","type":"neticrm_fpm","init":"neticrm-6.sh"}
EOF
}

if [ "$#" -lt 2 ]; then
  show_help
  exit 1
else
  IFS='/' read -r -a INPUT <<< "$1"
  LINODE="${INPUT[0]}"
  SITE="${INPUT[1]}"
  TARGET="$BASE/target/$LINODE"
  PLAYBOOK="$BASE/ansible-docker/playbooks"
  DOCKER=$2
  MAIL="mail.yml"
  SITESET="neticrm-deploy.yml"
fi

for VAR in "$@"; do
  if [ "$VAR" = "--yes" ]; then
    PROMPT=0
  fi
  if [ "$VAR" = "--welcome-letter" ]; then
    WELCOME=1
  fi
done

create_site() {
  VARFILE=$1
  PLAYBOOK=$2
  echo "Creating site ..."
  /usr/local/bin/ansible-playbook -v $PLAYBOOK/$DOCKER --extra-vars "$VARFILE" --tags=start

  echo "Waiting site installation ..."
  # we needs this because when mail enable, we still running drupal download and install
  sleep 60
  /usr/local/bin/ansible-playbook -v $PLAYBOOK/$MAIL --extra-vars "@$TARGET/vmail" --extra-vars "target=$LINODE" --tags=stop
  /usr/local/bin/ansible-playbook -v $PLAYBOOK/$MAIL --extra-vars "@$TARGET/vmail" --extra-vars "target=$LINODE" --tags=start
  create_email

  /usr/local/bin/ansible-playbook -v $PLAYBOOK/$MAIL --extra-vars "@$TARGET/vmail_json" --extra-vars "$VARFILE" --tags=site-setting
  /usr/local/bin/ansible-playbook -v $PLAYBOOK/$SITESET --extra-vars "$VARFILE" --tags=single-site
  if [ "$WELCOME" -eq "1" ]; then
    /usr/local/bin/ansible-playbook -v $PLAYBOOK/$MAIL --extra-vars "$VARFILE" --tags=welcome
  fi
}

create_email() {
  file="$TARGET/vmail_account"
  json_file="$TARGET/vmail_json"
  email=$(cat "$file")
  IFS=' ' read -ra VAR <<< "$email"
  EMAIL_ACCOUNT="${VAR[0]}"
  EMAIL_PASSWORD="${VAR[1]}"
  echo {\"email\":[{\"username\":\""$EMAIL_ACCOUNT"\", \"password\":\""$EMAIL_PASSWORD"\"}]} > "$json_file"
}

# ====================
if [ -f "$TARGET/$SITE" ]; then
  EXTRAVARS="@$TARGET/$SITE"
  cat << EOF
Command will be execute:
  ansible-playbook docker.yml --extra-vars "$EXTRAVARS" --tags=start
  ansible-playbook mail.yml --extra-vars "@$TARGET/vmail" --tags=stop
  ansible-playbook mail.yml --extra-vars "@$TARGET/vmail" --tags=start
  ansible-playbook backup.yml --extra-vars "$EXTRAVARS" --tags=single-site
  ansible-playbook neticrm-deploy.yml --extra-vars "$EXTRAVARS" --tags=single-site

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
      * ) 
        echo "invalid"
        exit 1
        ;;
    esac
  fi
else
  echo -e "\e[1;31m[File or target not found]\e[0m"
  show_help
  exit 1
fi
