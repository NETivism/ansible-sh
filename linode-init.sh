#!/bin/bash

BASE=/etc/ansible
# Usage info
show_help() {
cat << EOF
Help: 
  Usage:
    $0 linode_name hostname

  This script will initialize your linode, include these step:
    - Assume you'll use "answerable" for ansible login user
    - First will login in root, will ask root password for once
    - Put your key at $BASE/ansible-docker/playbooks/roles/init/files/authorized_key
    - Add authorized_key for "answerable" further use
    - Install docker and some other packages

EOF
}

if [ "$#" -lt 2 ]; then
  show_help
  exit 0
else
  TARGET=$1
  HOSTNAME=$2
fi



read -p "You need to prepared authorized_key and root password. Really want to go? (y/n)" CHOICE 
case "$CHOICE" in 
  y|Y )
    linode-linode group -g "ansible" -l "$TARGET"
    IP=$(linode show $TARGET | grep 'ips' | awk '{print $2}')
    if [ -n "$IP"]; then
      echo "$IP $TARGET" >> /etc/hosts
      ssh-keyscan $IP >> ~/.ssh/known_hosts
    fi;
    ansible-playbook -k $BASE/ansible-docker/playbooks/init.yml --extra-vars="target=$TARGET deployer=answerable hostname=$HOSTNAME"
    ansible-playbook $BASE/ansible-docker/playbooks/bootstrap-jessie.yml --extra-vars "target=$TARGET"
    ansible-playbook $BASE/ansible-docker/playbooks/rolling_upgrade.yml --extra-vars "target=$TARGET"
    ansible-playbook $BASE/ansible-docker/playbooks/security.yml --extra-vars "target=$TARGET"
    ansible-playbook $BASE/ansible-docker/playbooks/neticrm-deploy.yml --extra-vars "target=$TARGET" -t load,deploy-6,deploy-7
    ansible-playbook $BASE/ansible-docker/playbooks/mail.yml --extra-vars "@$BASE/target/$TARGET/vmail" -t start
    ;;
  n|N ) 
    exit 1
    ;;
  * ) echo "invalid";;
esac
