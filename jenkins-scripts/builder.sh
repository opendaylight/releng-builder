#!/bin/bash

yum clean all
yum install -y python-{tox,virtualenv} xmlstarlet

# vim: sw=2 ts=2 sts=2 et :
