#!/bin/bash

# Usage info
show_help() {
cat << EOF
Help: 
  Usage:
    $0 linode_name

  This script will initialize your linode, include these step:
    - Assume you'll use "answerable" for ansible login user
    - First will login in root, will ask root password for once
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


BASE=/etc/ansible

read -p "Did you prepared your authorized_key and root password? (y/n)" CHOICE 
case "$CHOICE" in 
  y|Y ) 
    ansible-playbook -k -i /etc/ansible/linode-inventory $BASE/ansible-docker/playbooks/init.yml --extra-vars="target=$TARGET deployer=answerable"
    ansible-playbook -i /etc/ansible/linode-inventory $BASE/ansible-docker/playbooks/bootstrap-jessie.yml --extra-vars "target=$TARGET"
    ;;
  n|N ) 
    exit 1
    ;;
  * ) echo "invalid";;
esac
