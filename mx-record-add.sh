#!/bin/bash

if [ -n "$1" ]; then
  DOMAIN_ID=$(linode-cli --text --suppress-warnings --no-headers --format "id,ipv4" domains list --domain neticrm.com)
  LINODE_IP=$(linode-cli --text --suppress-warnings --no-headers --format "ipv4" linodes list --label $1)
  if [ -n "$DOMAIN_ID" ] && [ -n "$LINODE_IP" ]; then
    EXISTS=$(linode-cli --text --no-headers domains records-list $DOMAIN_ID | grep MX | grep $1)
    if [ -z "$EXISTS" ]; then
      CMD="linode-cli --text --no-headers domains records-create $DOMAIN_ID --name $1 --type MX --priority 10 --target $1.neticrm.com"
      echo $CMD
      eval $CMD
    else
      echo "MX $1 already exists"
    fi
    EXISTS=$(linode-cli --text --no-headers domains records-list $DOMAIN_ID | grep A | grep $1)
    if [ -z "$EXISTS" ]; then
      CMD="linode-cli --text --no-headers domains records-create $DOMAIN_ID --name $1 --type A --target $LINODE_IP"
      echo $CMD
      eval $CMD
    else
      echo "A $1 already exists"
    fi
    EXISTS=$(linode-cli --text --no-headers domains records-list $DOMAIN_ID | grep TXT | grep $1)
    if [ -z "$EXISTS" ]; then
      CMD="linode-cli --text --no-headers domains records-create $DOMAIN_ID --name $1 --type TXT --target \"v=spf1 include:spf.neticrm.net ~all\""
      echo $CMD
      eval $CMD
    else
      echo "TXT SPF $1 already exists"
    fi
  fi
fi
