#!/bin/bash

function check_status() {
  # Status codes
  # 1 - running
  # 2 - suspend
  # 3 - clear DNS
  # 11 - pending to create
  # 22 - pending to suspend
  # 33 - pending to clear DNS
  STATUS_CODE=$1
  JSON_FILE=$2
  PLAYBOOK_BASE=/etc/ansible/ansible-docker/playbooks
  SCRIPT_BASE=/etc/ansible/ansible-sh
  case "$STATUS_CODE" in
    1)
      ;;
    2)
      ;;
    3)
      ;;
    11)
      TARGET=`jq -r .target $JSON_FILE`
      DOMAIN=`jq -r .domain $JSON_FILE`
      $SCRIPT_BASE/create-site.sh $TARGET/$DOMAIN docker.yml --yes
      jq -c '.status=1' $JSON_FILE > /tmp/$DOMAIN && mv /tmp/$DOMAIN $JSON_FILE
      ;;
    22)
      TARGET=`jq -r .target $JSON_FILE`
      DOMAIN=`jq -r .domain $JSON_FILE`
      $SCRIPT_BASE/suspend-site.sh $TARGET/$DOMAIN docker.yml --yes
      #ansible-playbook $PLAYBOOK_BASE/docker.yml --extra-vars "@$JSON_FILE" --tags suspend
      jq -c '.status=2' $JSON_FILE > /tmp/$DOMAIN && mv /tmp/$DOMAIN $JSON_FILE
      ;;
    33)
      TARGET=`jq -r .target $JSON_FILE`
      DOMAIN=`jq -r .domain $JSON_FILE`
      ansible-playbook $PLAYBOOK_BASE/dns.yml --extra-vars "@$JSON_FILE" --tags remove
      jq -c '.status=3' $JSON_FILE > /tmp/$DOMAIN && mv /tmp/$DOMAIN $JSON_FILE
      ;;
  esac
}

FILES="/etc/ansible/target/*/*"
for f in $FILES
do
  if [ "$(( $(date +"%s") - $(stat -c "%Y" $f) ))" -lt "600" ]; then
    STATUS=`jq -r .status $f`
    check_status $STATUS $f
  fi
done
