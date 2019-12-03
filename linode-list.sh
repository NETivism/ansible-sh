#!/bin/bash
linode-cli --text --suppress-warnings --no-headers --format label linodes list > /etc/ansible/inventory/linode
