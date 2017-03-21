#!/bin/bash

BASE=/etc/ansible
# Usage info
show_help() {
cat << EOF
Help: 
  Usage:
    $0 linode_name hostname host
    $0 neticrm-d5 m5.t2.neticrm.net m5.t2

  This script will initialize your linode, include these step:
    - Assume you'll use "answerable" for ansible login user
    - First will login in root, will ask root password for once
    - Put your key at $BASE/ansible-docker/playbooks/roles/init/files/authorized_key
    - Add authorized_key for "answerable" further use
    - Install docker and some other packages

EOF
}

if [ "$#" -lt 3 ]; then
  show_help
  exit 0
else
  TARGET=$1
  HOSTNAME=$2
  HOST=$3
fi



read -p "You need to prepared authorized_key into palybook init roles files. Really want to go? (y/n)" CHOICE 
case "$CHOICE" in 
  y|Y )
    linode-linode group -g "ansible" -l "$TARGET"
    IP=$(linode show $TARGET | grep 'ips' | awk '{print $2}')
    if [ -n "$IP" ]; then
      echo "$IP $TARGET" >> /etc/hosts
      ssh-keyscan $IP >> ~/.ssh/known_hosts
    fi

    # clear linode-inventory cache
    if [ -f /tmp/linode-inventory.json ]; then
      rm -f /tmp/linode-inventory.json
    fi

    # start
    echo "[0] Start init ..."
    read -p "Enter your superuser(with sudo permission) of remote host: " -e -i root LOGINNAME
    if [ -n "$LOGINNAME" ]; then
      echo "Login with remote user '$LOGINNAME' with password ... "
      ansible-playbook -u $LOGINNAME -k -b --become-method=sudo --ask-become-pass $BASE/ansible-docker/playbooks/init.yml --extra-vars="target=$TARGET deployer=answerable hostname=$HOSTNAME host=$HOST"
    fi;

    echo "[1] Start bootstrap ..."
    ansible-playbook $BASE/ansible-docker/playbooks/bootstrap-jessie.yml --extra-vars "target=$TARGET"
    echo "[2] Start fqdn ..."
    ansible-playbook $BASE/ansible-docker/playbooks/fqdn.yml --extra-vars "target=$TARGET"
    echo "[3] Start nginx ..."
    ansible-playbook $BASE/ansible-docker/playbooks/nginx.yml --extra-vars "target=$TARGET" -t reload
    echo "[4] Start rolling upgrade ..."
    ansible-playbook $BASE/ansible-docker/playbooks/rolling_upgrade.yml --extra-vars "target=$TARGET"
    echo "[5] Start security ..."
    ansible-playbook $BASE/ansible-docker/playbooks/security.yml --extra-vars "target=$TARGET"
    echo "[6] Start neticrm deploy ..."
    ansible-playbook $BASE/ansible-docker/playbooks/neticrm-deploy.yml --extra-vars "target=$TARGET" -t load,deploy-6,deploy-7
    echo "[7] Start mail ..."
    ansible-playbook $BASE/ansible-docker/playbooks/mail.yml --extra-vars "target=$TARGET" -t start
    echo "[8] Start user ..."
    ansible-playbook $BASE/ansible-docker/playbooks/user.yml --extra-vars "target=$TARGET" -t mount
    ;;
  n|N ) 
    exit 1
    ;;
  * ) echo "invalid";;
esac
