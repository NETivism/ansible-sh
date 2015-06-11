#!/bin/bash

# Usage info
show_help() {
cat << EOF
Help: 
  Usage:
    linode-add.sh 'linode_id=173462 api_key=your_key name=test plan=1 datacenter=8 distribution=140 swap=512'
  datacenter: 8(Tokyo) or 9(Singapore)
  distribution: please always use 140(debian jessie)
  plan: 1,2,4,8 GB mem

  Without prompt:
    linode-add.sh 'linode_id=173462 api_key=your_key name=test plan=1 datacenter=8 distribution=140 swap=512' --yes

  Add new (without linode_id):
    linode-add.sh 'api_key=your_key name=test plan=1 datacenter=8 distribution=140 swap=512'

  Update linode (with linode_id):
    linode-add.sh 'api_key=your_key name=test plan=1 datacenter=8 distribution=140 swap=512'

EOF
}

linode_add() {
  VAR=$1
  echo "Add linode ..."
  #ansible local -c local -m linode -a '$VAR'
}

if [ "$#" -lt 1 ]; then
  show_help
  exit 0
else
  ARGS=$1
fi

PROMPT=1
for VAR in "$@"; do
  if [ "$VAR" = "--yes" ]; then
    PROMPT=0
  fi
done

# ====================
cat << EOF
Command will be execute:
  ansible local -c local -m linode -a '$VAR'

EOF
if [ $PROMPT -eq 0 ]; then
  linode_add $ARGS
else
  read -p "Are you really want to create site? (y/n)" CHOICE 
  case "$CHOICE" in 
    y|Y ) 
      linode_add $ARGS
      ;;
    n|N ) 
      exit 1
      ;;
    * ) echo "invalid";;
  esac
fi

