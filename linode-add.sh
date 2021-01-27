#!/bin/bash

# Usage info
show_help() {
  echo "Example:"
  echo "  sudo ./linode-add.sh --region ap-northeast --image linode/debian10 --tags securemx --swap_size 512 --type g6-nanode-1 --label mx100"
  echo "Types:"
  linode-cli --format="id,label" linodes types
}

linode_add() {
  USER=$(cat /etc/ansible/ansible.cfg | grep remote_user | awk '{print $3}')
  #AUTH_KEY=$(cat /etc/ansible/playbooks/roles/init/files/authorized_keys)
  PASSWORD=$(date +%s | sha256sum | base64 | head -c 32 ; echo)
  if [ -n "$AUTH_KEY" ]; then
    CMD="linode-cli linodes create --authorized_keys \"$AUTH_KEY\" --authorized_users "$USER" --root_pass $PASSWORD $ARGS"
  else
    CMD="linode-cli linodes create $ARGS --root_pass $PASSWORD"
  fi
  echo $CMD
  eval $CMD
  echo "Root Password: $PASSWORD"
}

if [ "$#" -lt 1 ]; then
  show_help
  exit 0
else
  for VAR in "$@"; do
    ARGS="$ARGS $VAR"
  done
  linode_add
fi
