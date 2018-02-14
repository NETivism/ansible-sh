#!/bin/bash

usage() {
  echo "Usage: `basename $0` [-k API_KEY]"
  exit 1
}

[ $# -eq 0 ] && usage

# Get parameters by getopts command
while getopts k:? OPTION
do
  case $OPTION in
    k)
      API_KEY=$OPTARG
      ;;
    \?)
      usage
      ;;
  esac
done

# This script must be assign an API key
if [ -z "$API_KEY" ]; then
  echo "You must specify API_KEY with -k option"
  exit
fi

RUNNING=0
# Check target file status and do something
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
  PLAYBOOK_BASE=/etc/ansible/playbooks
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
      RUNNING=1
      $SCRIPT_BASE/create-site.sh $TARGET/$DOMAIN docker.yml --yes --welcome-letter
      RESULT=$?
      if [ $RESULT -eq 0 ]; then
        jq -c '.status=1' $JSON_FILE > /tmp/$DOMAIN && mv /tmp/$DOMAIN $JSON_FILE && chown neticrm:neticrm $JSON_FILE
        curl -X POST https://neticrm.tw/neticrm/ansible/$DOMAIN/1?k=$API_KEY
      fi  
      ;;
    22)
      TARGET=`jq -r .target $JSON_FILE`
      DOMAIN=`jq -r .domain $JSON_FILE`
      RUNNING=2
      $SCRIPT_BASE/suspend-site.sh $TARGET/$DOMAIN docker.yml --yes
      RESULT=$?
      if [ $RESULT -eq 0 ]; then
        jq -c '.status=2' $JSON_FILE > /tmp/$DOMAIN && mv /tmp/$DOMAIN $JSON_FILE && chown neticrm:neticrm $JSON_FILE
        curl -X POST https://neticrm.tw/neticrm/ansible/$DOMAIN/2?k=$API_KEY
      fi
      ;;
    33)
      TARGET=`jq -r .target $JSON_FILE`
      DOMAIN=`jq -r .domain $JSON_FILE`
      RUNNING=3
      $SCRIPT_BASE/remove-site.sh $TARGET/$DOMAIN --yes
      RESULT=$?
      if [ $RESULT -eq 0 ]; then
        jq -c '.status=3' $JSON_FILE > /tmp/$DOMAIN && mv /tmp/$DOMAIN $JSON_FILE && chown neticrm:neticrm $JSON_FILE
        curl -X POST https://neticrm.tw/neticrm/ansible/$DOMAIN/3?k=$API_KEY
      fi
      ;;
  esac
}

FILES=$(find /etc/ansible/target/*/*.* -mmin -3 -not -name "*.old" -printf "%T@ %p\n" | sort -n | awk '{ print $2 }')
for FILE in $FILES
do
  echo "$(date +"%Y-%m-%d %H:%M:%S") Trying $FILE..."
  # only run first matches, others will be done in next cron
  if [ $RUNNING -eq 0 ]; then
    echo "=============================================================="
    echo "$(date +"%Y-%m-%d %H:%M:%S") Start checking $FILE"
    STATUS=`jq -r .status $FILE`
    echo "Status: $STATUS"
    check_status $STATUS $FILE
    echo "$(date +"%Y-%m-%d %H:%M:%S") End checking $FILE"
    echo "=============================================================="
  else
    echo "SKIP - $FILE"
    $(touch $FILE);
  fi
done
echo "$(date +"%Y-%m-%d %H:%M:%S") DONE checking"
