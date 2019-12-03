#!/bin/bash
#linode-cli --text --suppress-warnings --no-headers --format label,ipv4 linodes list > /tmp/linode-inventory.txt
#sed -i 's/^/[/g' /tmp/linode-inventory.txt && sed -i 's/\t/]\n/g' /tmp/linode-inventory.txt
#cp -f /tmp/linode-inventory.txt /etc/ansible/inventory/linode
linode-cli --text --suppress-warnings --no-headers --format label linodes list > /etc/ansible/inventory/linode
