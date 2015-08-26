#!/bin/bash

BASE=/etc/ansible
# Usage info
show_help() {
cat << EOF
Help: 
  Usage:
    $0 linode_name

  This script will initialize your linode, include these step:
    - Assume you'll use "answerable" for ansible login user
    - First will login in root, will ask root password for once
    - Put your key at $BASE/ansible-docker/playbooks/roles/init/files/authorized_key
    - Add authorized_key for "answerable" further use
    - Install docker and some other packages

EOF
}

if [ "$#" -lt 1 ]; then
  show_help
  exit 0
else
  TARGET=$1
fi



read -p "You need to prepared authorized_key and root password. Really want to go? (y/n)" CHOICE 
case "$CHOICE" in 
  y|Y ) 
    ansible-playbook -k $BASE/ansible-docker/playbooks/init.yml --extra-vars="target=$TARGET deployer=answerable"
    ansible-playbook $BASE/ansible-docker/playbooks/bootstrap-jessie.yml --extra-vars "target=$TARGET"
    ;;
  n|N ) 
    exit 1
    ;;
  * ) echo "invalid";;
esac
