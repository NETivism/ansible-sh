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
    create-site.sh linode_target/file_name docker.yml

  Create site without prompt:
    create-site.sh docker1/test.com docker.yml --yes

EOF
}

create_site() {
  VARS=$1
  echo "Creating site ..."
  ansible-playbook -i /etc/ansible/linode-inventory $BASE/ansible-docker/playbooks/$PLAYBOOK --extra-vars '$VARS' --tags=start
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
  EXTRAVARS=`cat $BASE/target/$TARGET`
  cat << EOF
Command will be execute:
  ansible-playbook -i /etc/ansible/linode-inventory playbooks/docker.yml --extra-vars '$EXTRAVARS' --tags=start"

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

