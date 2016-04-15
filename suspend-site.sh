#!/bin/bash

# Usage info
show_help() {
cat << EOF
Help: 
  Assume your base is /etc/ansible, 
  BASE/ansible-docker/playbooks - have your playbooks
  BASE/target - have your docker hosts inventories
  BASE/target/target_name/* - extravars json, usally naming by domain name

  Suspend site:
    $0 linode_target/json_file playbook.yml

  Suspend site without prompt:
    $0 server1/test.com docker.yml --yes # stop docker and redirect nginx
    $0 server1/test.com nginx.yml --yes # only redirect nginx, keep docker start
EOF
}

suspend_site() {
  VARFILE=$1
  PLAYBOOK=$2
  echo "Creating site ..."
  ansible-playbook $PLAYBOOK/$DOCKER --extra-vars "$VARFILE" --tags=suspend
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
  ansible-playbook docker.yml --extra-vars "$EXTRAVARS" --tags=suspend

EOF
  if [ $PROMPT -eq 0 ]; then
    suspend_site $EXTRAVARS $PLAYBOOK
  else
    read -p "Are you really want to suspend site? (y/n)" CHOICE 
    case "$CHOICE" in 
      y|Y ) 
        suspend_site $EXTRAVARS $PLAYBOOK
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

