#!/usr/bin/bash
# -*- mode: shell-script; fill-column: 80; -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2014, Joyent, Inc.
#

export PS4='[\D{%FT%TZ}] ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -o xtrace

PATH=/opt/local/bin:/opt/local/sbin:/usr/bin:/usr/sbin

role=papi
# Local SAPI manifests:
CONFIG_AGENT_LOCAL_MANIFESTS_DIRS=/opt/smartdc/$role

# Include common utility functions (then run the boilerplate)
source /opt/smartdc/boot/lib/util.sh
sdc_common_setup

# Cookie to identify this as a SmartDC zone and its role
mkdir -p /var/smartdc/$role

mkdir -p /opt/smartdc/$role/etc
/usr/bin/chown -R root:root /opt/smartdc

# Add build/node/bin and node_modules/.bin to PATH
echo "" >>/root/.profile
echo "export PATH=\$PATH:/opt/smartdc/$role/build/node/bin:/opt/smartdc/$role/node_modules/.bin" >>/root/.profile

PACKAGES_BOOTSTRAP=/opt/smartdc/$role/etc/packages.json

UFDS_ADMIN_UUID=$(json -f ${METADATA} ufds_admin_uuid)

echo "[" >> $PACKAGES_BOOTSTRAP

echo "Getting package information"
# packages=$(/usr/sbin/mdata-get packages)
PACKAGES=($(json -f ${METADATA} packages))
# name:ram:swap:disk:cap:nlwp:iopri:uuid
tLen=${#PACKAGES[@]}
let "lastestComma = $tLen - 1"

for (( i=0; i<${tLen}; i++ ));
do
  pkg=${PACKAGES[$i]}
  name=$(echo ${pkg} | cut -d ':' -f 1)
  uuid=$(echo ${pkg} | cut -d ':' -f 8)
  # TBD: Decide if default package should be configurable
  # (can be changed from adminui post setup).
  if [[ "${name}" == "sdc_128" ]]; then
    default='true'
  else
    default='false'
  fi

  echo "{
    \"uuid\": \"${uuid}\",
    \"active\": true,
    \"cpu_cap\": \"$(echo ${pkg} | cut -d ':' -f 5)\",
    \"default\": $default,
    \"max_lwps\": $(echo ${pkg} | cut -d ':' -f 6),
    \"max_physical_memory\": $(echo ${pkg} | cut -d ':' -f 2),
    \"max_swap\": $(echo ${pkg} | cut -d ':' -f 3),
    \"name\": \"${name}\",
    \"quota\": $(echo ${pkg} | cut -d ':' -f 4),
    \"vcpus\": 1,
    \"version\": \"1.0.0\",
    \"zfs_io_priority\": $(echo ${pkg} | cut -d ':' -f 7),
    \"owner_uuid\": \"${UFDS_ADMIN_UUID}\"
  }" >> $PACKAGES_BOOTSTRAP

  # Do not append a comma to the last element
  if [ "$i" -lt "$lastestComma" ]; then
    echo "," >> $PACKAGES_BOOTSTRAP
  fi

  # Cleanup variables before next loop iteration
  unset pkg
  unset name
  unset uuid
done

echo "]" >> $PACKAGES_BOOTSTRAP

echo "Adding log rotation"
sdc_log_rotation_add amon-agent /var/svc/log/*amon-agent*.log 1g
sdc_log_rotation_add config-agent /var/svc/log/*config-agent*.log 1g
sdc_log_rotation_add registrar /var/svc/log/*registrar*.log 1g
sdc_log_rotation_add $role /var/svc/log/*$role*.log 1g
sdc_log_rotation_setup_end

# All done, run boilerplate end-of-setup
sdc_setup_complete

exit 0
