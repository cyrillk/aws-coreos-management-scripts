#!/bin/bash

readonly args=("$@")

readonly AWS_KEY=${args[0]}
readonly AWS_SECRET_KEY=${args[1]}

if [ -z "$AWS_KEY" ]; then
   echo "Missing 'AWS key' parameter"
   exit 1
fi

if [ -z "$AWS_SECRET_KEY" ]; then
  echo "Missing 'AWS secret key' parameter"
   exit 1
fi

function call {
  local CLUSTER_ID="$1"

  local IP
  IP=$(aws ec2 describe-instances --filter Name=tag:cluster_id,Values=$CLUSTER_ID | jq '.Reservations[].Instances[].PublicIpAddress' | head -n 1 | sed 's/\"//g')

  local TUNNEL
  TUNNEL="FLEETCTL_TUNNEL=$IP"

  local MACHINES
  MACHINES=$(env $TUNNEL fleetctl list-machines | cut -d'.' -f1 | awk 'NR>1' | head -n 1)

  for MACHINE_ID in $MACHINES; do
    printf '\n'
    echo "Cluster $CLUSTER_ID"
    printf '%32s\n' | tr ' ' =
    env $TUNNEL fleetctl ssh $MACHINE_ID "etcdctl set /efset/services/secrets/aws/access_key $AWS_KEY 1> /dev/null"
    env $TUNNEL fleetctl ssh $MACHINE_ID "etcdctl set /efset/services/secrets/aws/secret_access_key $AWS_SECRET_KEY 1> /dev/null"
    echo "Updated.."
  done
}

readonly CLUSTERS=$(aws ec2 describe-instances | jq ".Reservations[].Instances[].Tags[] | select(.Key | contains(\"cluster_id\")) | .Value" | sort | uniq | sed 's/\"//g')

for ID in $CLUSTERS; do
  call $ID
done
