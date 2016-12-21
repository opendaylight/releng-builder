#!/usr/bin/expect
# This script starts the karaf shell and sends the password for SSH auth.
# Further tests in karaf shell can be done here

# Default password
set password "karaf"

# OpenDaylight service requires some time after it starts for a successful
# SSH connection
sleep 10

# SSH into Karaf shell
spawn ssh -p 8101 -o StrictHostKeyChecking=no karaf@127.0.0.1

expect "Password: "
send "$password"

# TODO Add further tests here
