#!/bin/bash
set -euo pipefail
readonly IFS=$'\n\t'

function call {
  local CLUSTER_ID="$1"

  local IP
  IP=$(aws ec2 describe-instances --filter Name=tag:cluster_id,Values=$CLUSTER_ID | jq '.Reservations[].Instances[].PublicIpAddress' | head -n 1 | sed 's/\"//g')

  local TUNNEL
  TUNNEL="FLEETCTL_TUNNEL=$IP"

  local MACHINES
  MACHINES=$(env $TUNNEL fleetctl list-machines -l -no-legend -fields machine)

  printf "Cluster %s\n" "$CLUSTER_ID"
  printf "%32s\n" | tr ' ' =

  for MACHINE_ID in $MACHINES; do
    printf "\nMachine %s\n" "$MACHINE_ID"
    env $TUNNEL fleetctl ssh "$MACHINE_ID" "docker ps --format '{{.Image}}\t{{.Names}}\t{{.RunningFor}} ago\t{{.Status}}'"
  done
}

readonly CLUSTERS=$(aws ec2 describe-instances | jq ".Reservations[].Instances[].Tags[] | select(.Key | contains(\"cluster_id\")) | .Value" | sort | uniq | sed 's/\"//g')

printf "\n"

for ID in $CLUSTERS; do
  call $ID
  printf "\n"
done
