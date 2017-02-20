#!/bin/bash

# Usage info
show_help() {
cat << EOF
Help: 
  Usage:
    $0 'linode_id=173462 api_key=your_key name=test plan=1 datacenter=11 distribution=140 swap=512'
  datacenter: 8(Tokyo) or 9(Singapore) or 11(Tokyo 2)
  distribution: please always use 140(debian jessie)
  plan: 1,2,4,8 means 1/2/4/8 gb plan

  Without prompt:
    linode-add.sh 'linode_id=173462 api_key=your_key name=test plan=1 datacenter=11 distribution=140 swap=512' --yes

  Add new (without linode_id):
    linode-add.sh 'api_key=your_key name=test plan=1 datacenter=11 distribution=140 swap=512'

  Update linode (must with linode_id):
    linode-add.sh 'linode_id=173462 api_key=your_key name=test plan=1 datacenter=8 distribution=140 swap=512'

EOF
}

linode_add() {
  VAR="$*"
  echo "Add linode ... '${VAR}'"
  CMD="ansible all -i "localhost," -c local -m linode -a '$VAR'"
  eval $CMD
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
  ansible all -i "localhost," -c local -m linode -a '$ARGS'

EOF
if [ $PROMPT -eq 0 ]; then
  linode_add $ARGS
else
  read -p "Are you really want to create linode? (y/n)" CHOICE 
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

