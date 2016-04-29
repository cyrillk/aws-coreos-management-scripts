#!/bin/bash

if [ -z "$FLEETCTL_TUNNEL" ]; then
   echo "Missing FLEETCTL_TUNNEL environment variable"
   exit 1
fi

for machine in $(fleetctl list-machines --no-legend --full | awk '{ print $1;}'); do
  fleetctl ssh "$machine" "docker ps --format '{{.ID}}\t{{.Image}}\t{{.Names}}\t{{.RunningFor}} ago\t{{.Status}}'"
done
