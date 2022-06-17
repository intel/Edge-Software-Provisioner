#!/bin/sh

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

if [ -f /data/gitea/conf/app.ini ] && (cat /data/gitea/conf/app.ini | grep INSTALL_LOCK | grep true 2>&1 > /dev/null ); then
  echo "GitTea already configured"
else
  echo "configuring GitTea"
  /usr/bin/entrypoint &
  sleep 5
  gitea manager shutdown
  sed -i 's/INSTALL_LOCK[ \t]*= false/INSTALL_LOCK   = true/' /data/gitea/conf/app.ini && \
  sed -i 's/\[repository\]/\[repository\]\nDEFAULT_PRIVATE=public\nENABLE_PUSH_CREATE_USER=true\nENABLE_PUSH_CREATE_ORG=true/' /data/gitea/conf/app.ini && \
  sed -i 's/\[database\]/\[database\]\nLOG_SQL = false/' /data/gitea/conf/app.ini
  sleep 5
  /usr/bin/entrypoint &
  sleep 5
  gitea migrate
  sleep 5
  while (! gitea admin user create --admin --username mirror --password mirror --email mirror@localhost --must-change-password=false ); do 
    echo \"Waiting for Gitea Database\"; 
    sleep 5; 
  done
  sleep 3
  gitea manager shutdown
  chown git:git /data/gitea/gitea.db
  sleep 5
fi

exec /usr/bin/entrypoint