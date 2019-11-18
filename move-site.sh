#!/bin/bash

WELCOME=0
BASE=/etc/ansible
LINODE=""
set -e

show_help() {
cat << EOF
Help: 
  Assume your base is /etc/ansible, 
  BASE/playbooks - have your playbooks
  BASE/target - have your docker hosts inventories
  BASE/target/json - your site domain

  move site:
    $0 linode/source_json_file linode/destination_json_file playbook.yml

EOF
}
if [ "$#" -lt 3 ]; then
  show_help
  exit 1
else
  IFS='/' read -r -a INPUT <<< "$1"
  LINODEA="${INPUT[0]}"
  SITEA="${INPUT[1]}"
  TARGETA="$BASE/target/$LINODEA"

  IFS='/' read -r -a INPUT <<< "$2"
  LINODEB="${INPUT[0]}"
  SITEB="${INPUT[1]}"
  TARGETB="$BASE/target/$LINODEB"
  PLAYBOOK="$BASE/playbooks"
  YML=$3
  IP=`cat /etc/hosts | grep $LINODEB | awk '{ print $1 }'`
  FQDN=`dig -x "$IP" +short | head -1 | sed 's/\.$//'`
  SUBDOMAIN=`sed 's/\.neticrm\.tw//g' <<< "$SITEB"`
fi

copy_site_json() {
  if [ -f $TARGETB/$SITEB ]; then
    echo -e "\e[1;31mCreate JSON Error! "$TARGETB/$SITEB" exists. Abort.\e[0m"
    exit 1;
  fi
  # find max port number of exists site settings
  PORT_WWW=$(find $TARGETB/*.* | xargs cat | jq '.port_www' | uniq | sort -n -r | head -1)
  PORT_DB=$(find $TARGETB/*.* | xargs cat | jq '.port_db' | uniq | sort -n -r | head -1)
  PORT_WWW=$((PORT_WWW+1))
  PORT_DB=$((PORT_DB+1))
  if [ -n "$PORT_WWW" ] && [ -n "$PORT_DB" ]; then
    cat $TARGETA/$SITEA | jq --arg TARGET_NEW $LINODEB --arg DOMAIN_NEW $SITEB --arg PORT_WWW $PORT_WWW  --arg PORT_DB $PORT_DB '.target = $TARGET_NEW | .domain = $DOMAIN_NEW | .port_www = ($PORT_WWW | tonumber) | .port_db = ($PORT_DB | tonumber)' > $TARGETB/$SITEB
    echo "Successful created $TARGETB/$SITEB"
    echo "Previous settings:"
    cat $TARGETA/$SITEA | jq
    echo "New settings:"
    cat $TARGETB/$SITEB | jq
  fi
}
create_site() {
  if [ ! -f $TARGETB/$SITEB ]; then
    echo -e "\e[1;31mCreate Site Error! "$TARGETB/$SITEB" doesn't exists. Abort.\e[0m"
    exit 1;
  fi
  VARFILE=$1
  echo "Creating site ..."
  /usr/local/bin/ansible-playbook -v $PLAYBOOK/$YML --extra-vars "$VARFILE" --tags=start

  echo "Waiting site installation ..."
  # we needs this because when mail enable, we still running drupal download and install
  sleep 60
  rm -f $TARGET/vmail_json #clear vmail_json to prevent wrong assignment
  /usr/local/bin/ansible-playbook -v $PLAYBOOK/mail.yml --extra-vars "@$TARGETB/vmail" --extra-vars "target=$LINODEB" --tags=stop
  /usr/local/bin/ansible-playbook -v $PLAYBOOK/mail.yml --extra-vars "@$TARGETB/vmail" --extra-vars "target=$LINODEB" --tags=start
  if [ -f $TARGET/vmail_json ]; then
    /usr/local/bin/ansible-playbook -v $PLAYBOOK/mail.yml --extra-vars "@$TARGETB/vmail_json" --extra-vars "$VARFILE" --tags=site-setting
  fi
  /usr/local/bin/ansible-playbook -v $PLAYBOOK/neticrm-deploy.yml --extra-vars "$VARFILE" --tags=single-site
  ansible $LINODEB -b -m shell -a "cp /var/www/sites/$SITEB/sites/default/smtp.settings.php /tmp/smtp.settings.php.$SITEB"
}
copy_site_files() {
  echo "Stoping docker on both site"
  ansible $LINODEA -b -m shell -a "docker stop $SITEA"
  ansible $LINODEB -b -m shell -a "docker stop $SITEB"

  echo "Copying database files from $LINODEA to $LINODEB of $SITEB. This will take a while, be patient ..."
  ansible $LINODEB -b -m shell -a "rm -Rf /var/mysql/sites/$SITEB/* && chown -R answerable /var/mysql/sites/$SITEB"
  ansible $LINODEA -b -m shell -a "chown -R answerable /var/mysql/sites/$SITEA"
  echo "$LINODEA to local ..."
  rsync -al --info=progress2 answerable@$LINODEA:/var/mysql/sites/$SITEA /tmp/
  echo "local to $LINODEB ..."
  rsync -al --info=progress2 /tmp/$SITEA/ answerable@$LINODEB:/var/mysql/sites/$SITEB
  rm -Rf /tmp/$SITEA
  ansible $LINODEA -b -m shell -a "chown -R 101:102 /var/mysql/sites/$SITEA"
  ansible $LINODEB -b -m shell -a "chown -R 101:102 /var/mysql/sites/$SITEB"

  echo "Copying www files from $LINODEA to $LINODEB of $SITEB. This will take a while, be patient ..."
  ansible $LINODEB -b -m shell -a "rm -Rf /var/www/sites/$SITEB/* && chown -R answerable /var/www/sites/$SITEB"
  ansible $LINODEA -b -m shell -a "chown -R answerable /var/www/sites/$SITEA"
  echo "$LINODEA to local ..."
  rsync -al --info=progress2 answerable@$LINODEA:/var/www/sites/$SITEA /tmp/
  echo "local to $LINODEB ..."
  rsync -al --info=progress2 /tmp/$SITEA/ answerable@$LINODEB:/var/www/sites/$SITEB
  rm -Rf /tmp/$SITEA
  ansible $LINODEA -b -m shell -a "chown -R www-data:www-data /var/www/sites/$SITEA"
  ansible $LINODEB -b -m shell -a "chown -R www-data:www-data /var/www/sites/$SITEB"

  echo "File transfer completed. Doing clean up..."
  ansible $LINODEB -b -m shell -a "cp -f /var/www/sites/$SITEB/sites/default/smtp.settings.php /var/www/sites/$SITEB/sites/default/smtp.settings.php.bak"
  ansible $LINODEB -b -m shell -a "cp -f /tmp/smtp.settings.php.$SITEB /var/www/sites/$SITEB/sites/default/smtp.settings.php"
  /usr/local/bin/ansible $LINODEA -b -m shell -a "docker rm $SITEA"
  /usr/local/bin/ansible $LINODEB -b -m shell -a "docker start $SITEB"
}

neticrm_tw_config() {
  cd /var/www/sites/neticrm.tw
  # this will delete old site config
  # and update membership server belong record
  drush -l neticrm.tw neti-change-server $LINODEA/$SITEA $LINODEB/$SITEB
}

# ====================
if [ -f "$TARGETA/$SITEA" ]; then
  EXTRAVARS="@$TARGETB/$SITEB"
  cat << EOF
Command will move $TARGETA/$SITEA to $TARGETB/$SITEB

EOF
  read -p "Are you really want to move entier site? (y/n)" CHOICE 
  case "$CHOICE" in 
    y|Y ) 
      copy_site_json
      create_site $EXTRAVARS $PLAYBOOK
      copy_site_files
      neticrm_tw_config
      echo "Migrate complete."
      echo "You need to check DNS setting manually. Command may like this:"
      echo ""
      echo "    linode domain -a record-update -t CNAME -l neticrm.tw -m $SUBDOMAIN -R $FQDN"
      ;;
    n|N ) 
      exit 1
      ;;
    * ) 
      echo "invalid"
      exit 1
      ;;
  esac
else
  echo -e "\e[1;31m[File or target not found]\e[0m"
  show_help
  exit 1
fi
