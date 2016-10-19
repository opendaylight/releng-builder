#!/bin/bash

# Script to join a channel and say leave a message.

NICK=odl-notify-bot
SERVER=irc.freenode.net
PORT=6667
CHAN="#opendaylight-releng"
MESSAGE="SSH copy-failed see $JOB_NAME $BUILD_URL"

{
  cat << IRC
NICK $NICK
USER $NICK x y :$NICK
JOIN $CHAN
PRIVMSG $CHAN :$MESSAGE
IRC

  # Sleep to make sure irc connection completed and message sent.
  sleep 30
  echo QUIT
} | nc $SERVER $PORT

