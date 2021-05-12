#!/bin/sh

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

if (cat /data/gitea/conf/app.ini | grep INSTALL_LOCK | grep true 2>&1 > /dev/null ); then
  echo "GitTea already configured"
else
  /usr/bin/entrypoint &
  sleep 5
  gitea manager shutdown
  sed -i 's/INSTALL_LOCK[ \t]*= false/INSTALL_LOCK   = true/' /data/gitea/conf/app.ini && \
  sed -i 's/\[repository\]/\[repository\]\nDEFAULT_PRIVATE=public\nENABLE_PUSH_CREATE_USER=true\nENABLE_PUSH_CREATE_ORG=true/' /data/gitea/conf/app.ini
fi

if (cat /data/gitea/conf/app.ini | grep INSTALL_LOCK | grep true 2>&1 > /dev/null ); then
  echo "GitTea database already configured"
else
  sleep 5 && \
  while (! gitea admin create-user --admin --username mirror --password mirror --email mirror@localhost --must-change-password=false ); do 
    echo \"Waiting for Gitea Database\"; 
    sleep 5; 
  done
fi

exec /usr/bin/entrypoint