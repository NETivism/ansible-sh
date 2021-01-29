#!/bin/bash

if [ -n "$1" ]; then
  SUBNAME=$1
  echo "Sub-Domain Name: $SUBNAME"
  LINODE_NAME=${SUBNAME%.*}
  echo "Linode Name: $LINODE_NAME"
  DOMAIN_ID=$(linode-cli --text --suppress-warnings --no-headers --format "id,ipv4" domains list --domain neticrm.com)
  echo "Domain ID: $DOMAIN_ID"
  LINODE_IP=$(linode-cli --text --suppress-warnings --no-headers --format "ipv4" linodes list --label $LINODE_NAME)
  echo "Linode IPv4: $LINODE_IP"
  if [ -n "$DOMAIN_ID" ] && [ -n "$LINODE_IP" ]; then
    EXISTS=$(linode-cli --text --no-headers domains records-list $DOMAIN_ID | grep MX | grep $SUBNAME)
    if [ -z "$EXISTS" ]; then
      CMD="linode-cli --text --no-headers domains records-create $DOMAIN_ID --name $SUBNAME --type MX --priority 10 --target $SUBNAME.neticrm.com"
      echo $CMD
      eval $CMD
    else
      echo "MX $SUBNAME already exists"
    fi
    EXISTS=$(linode-cli --text --no-headers domains records-list $DOMAIN_ID | grep A | grep $SUBNAME)
    if [ -z "$EXISTS" ]; then
      CMD="linode-cli --text --no-headers domains records-create $DOMAIN_ID --name $SUBNAME --type A --target $LINODE_IP"
      echo $CMD
      eval $CMD
    else
      echo "A $SUBNAME already exists"
    fi
    EXISTS=$(linode-cli --text --no-headers domains records-list $DOMAIN_ID | grep CNAME | grep $SUBNAME)
    if [ -z "$EXISTS" ]; then
      CMD="linode-cli --text --no-headers domains records-create $DOMAIN_ID --name mail._domainkey.$SUBNAME --type CNAME --target dkim.secure.neticrm.com"
      echo $CMD
      eval $CMD
    else
      echo "A $SUBNAME already exists"
    fi
    EXISTS=$(linode-cli --text --no-headers domains records-list $DOMAIN_ID | grep TXT | grep $SUBNAME)
    if [ -z "$EXISTS" ]; then
      CMD="linode-cli --text --no-headers domains records-create $DOMAIN_ID --name $SUBNAME --type TXT --target \"v=spf1 include:spf.neticrm.net ~all\""
      echo $CMD
      eval $CMD
    else
      echo "TXT SPF $SUBNAME already exists"
    fi
  fi
  if [ -n "$LINODE_IP" ]; then
    CMD="linode-cli --text networking ip-update $LINODE_IP --rdns \"$SUBNAME.neticrm.com\""
    echo $CMD
    eval $CMD
  fi
fi
