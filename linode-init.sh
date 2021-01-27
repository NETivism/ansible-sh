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
    - Put your key at $BASE/playbooks/roles/init/files/authorized_key
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
    IN_HOSTS=$(cat /etc/hosts | grep $TARGET)
    if [ -z "$IN_HOSTS" ]; then
      IP=$(linode-cli --text --format="label,tags,ipv4" linodes list | grep $TARGET | awk '{ print $3 }')
      if [ -n "$IP" ]; then
        echo "$IP $TARGET" >> /etc/hosts
        ssh-keyscan $TARGET >> ~/.ssh/known_hosts
        ssh-keyscan $TARGET >> /root/.ssh/known_hosts
      fi
    fi

    IN_INVENTORY=$(cat $BASE/inventory/linode | grep $TARGET)
    if [ -z "$IN_INVENTORY" ]; then
      echo $TARGET >> $BASE/inventory/linode
    fi

    # start
    echo "[0] Start init ..."
    read -p "Enter your superuser(with sudo permission) of remote host: " -e -i root LOGINNAME
    if [ -n "$LOGINNAME" ]; then
      echo "Login with remote user '$LOGINNAME' with password ... "
      ansible-playbook -u $LOGINNAME -k -b --become-method=sudo --ask-become-pass $BASE/playbooks/init.yml --extra-vars="target=$TARGET deployer=answerable hostname=$HOSTNAME host=$HOST"
    else
      exit 1;
    fi;
    RESULT=$?
    if [ $RESULT -ne 0 ]; then exit 1; fi;

    echo "[1] Start bootstrap ..."
    CMD="ansible-playbook $BASE/playbooks/bootstrap-stretch.yml --extra-vars \"target=$TARGET\""
    echo $CMD
    bash -c "$CMD"
    RESULT=$?
    if [ $RESULT -ne 0 ]; then exit 1; fi;

    echo "[2] Start fqdn ..."
    CMD="ansible-playbook $BASE/playbooks/fqdn.yml --extra-vars \"target=$TARGET\""
    echo $CMD
    bash -c "$CMD"
    RESULT=$?
    if [ $RESULT -ne 0 ]; then exit 1; fi;

    echo "[3] Start nginx ..."
    CMD="ansible-playbook $BASE/playbooks/nginx.yml --extra-vars \"target=$TARGET\" -t reload"
    echo $CMD
    bash -c "$CMD"
    RESULT=$?
    if [ $RESULT -ne 0 ]; then exit 1; fi;

    echo "[4] Start rolling upgrade ..."
    CMD="ansible-playbook $BASE/playbooks/common.yml --extra-vars \"target=$TARGET\""
    echo $CMD
    bash -c "$CMD"
    RESULT=$?
    if [ $RESULT -ne 0 ]; then exit 1; fi;

    echo "[5] Start neticrm deploy ..."
    CMD="ansible-playbook $BASE/playbooks/neticrm-deploy.yml --extra-vars \"target=$TARGET\" -t load,deploy-6,deploy-7"
    echo $CMD
    bash -c "$CMD"
    RESULT=$?
    if [ $RESULT -ne 0 ]; then exit 1; fi;

    echo "[6] Start mail ..."
    CMD="ansible-playbook $BASE/playbooks/mail.yml --extra-vars \"target=$TARGET\" -t create"
    echo $CMD
    bash -c "$CMD"
    if [ $RESULT -ne 0 ]; then exit 1; fi;

    echo "[7] Start security ..."
    CMD="ansible-playbook $BASE/playbooks/security.yml --extra-vars \"target=$TARGET\""
    echo $CMD
    bash -c "$CMD"
    RESULT=$?
    if [ $RESULT -ne 0 ]; then exit 1; fi;


    CMD="ansible-playbook $BASE/playbooks/mail.yml --extra-vars \"target=$TARGET\" -t start"
    echo $CMD
    bash -c "$CMD"
    RESULT=$?
    if [ $RESULT -ne 0 ]; then exit 1; fi;

    echo "[8] Start user ..."
    CMD="ansible-playbook $BASE/playbooks/user.yml --extra-vars \"target=$TARGET\" -t mount"
    echo $CMD
    bash -c "$CMD"
    RESULT=$?
    if [ $RESULT -ne 0 ]; then exit 1; fi;

    echo "[9] Start letsencrypt ..."
    CMD="ansible-playbook $BASE/playbooks/letsencrypt.yml --extra-vars \"target=$TARGET\" -t install"
    echo $CMD
    bash -c "$CMD"
    RESULT=$?
    if [ $RESULT -ne 0 ]; then exit 1; fi;

    echo "[10] Start backup ..."
    CMD="ansible-playbook $BASE/playbooks/backup.yml --extra-vars \"target=$TARGET\""
    echo $CMD
    bash -c "$CMD"
    RESULT=$?
    if [ $RESULT -ne 0 ]; then exit 1; fi;
    ;;
  n|N ) 
    exit 1
    ;;
  * ) echo "invalid";;
esac
