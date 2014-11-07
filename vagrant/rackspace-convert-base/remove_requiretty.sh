#!/bin/bash

# vim: sw=2 ts=2 sts=2 et :

if [ ! -e /.autorelease ]; then
  /bin/sed -i 's/requiretty/!requiretty/' /etc/sudoers;
fi
