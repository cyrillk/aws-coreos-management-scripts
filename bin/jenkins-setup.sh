#!/bin/bash

readonly args=("$@")

readonly JENKINS_USER=${args[0]}
readonly JENKINS_EMAIL=${args[1]}
readonly JENKINS_PASS=${args[2]}

if [ -z "$JENKINS_USER" ]; then
  echo "Missing 'JENKINS_USER' parameter"
  exit 1
fi

if [ -z "$JENKINS_EMAIL" ]; then
  echo "Missing 'JENKINS_EMAIL' parameter"
  exit 1
fi

if [ -z "$JENKINS_PASS" ]; then
  echo "Missing 'JENKINS_PASS' parameter"
  exit 1
fi

function call {
  local CLUSTER_ID="$1"

  printf '\n'
  echo "Cluster $CLUSTER_ID"
  printf '%32s\n' | tr ' ' =

  local IP
  IP=$(aws ec2 describe-instances --filter Name=tag:cluster_id,Values=$CLUSTER_ID | jq '.Reservations[].Instances[].PublicIpAddress' | head -n 1 | sed 's/\"//g')

  local TUNNEL
  TUNNEL="FLEETCTL_TUNNEL=$IP"

  local SERVICES
  SERVICES=$(env $TUNNEL fleetctl list-units | cut -d'.' -f1 | awk 'NR>1' | grep jenkins@)

  for SERVICE in $SERVICES; do
    local DOCKER
    DOCKER=$(echo $SERVICE | tr '@' '-')

    env $TUNNEL fleetctl ssh $SERVICE "docker exec $DOCKER git config --global user.name $JENKINS_USER"
    env $TUNNEL fleetctl ssh $SERVICE "docker exec $DOCKER git config --global user.email $JENKINS_EMAIL"
    env $TUNNEL fleetctl ssh $SERVICE "docker exec $DOCKER git config --global credential.helper store"
    env $TUNNEL fleetctl ssh $SERVICE "docker exec $DOCKER /bin/bash -c \"echo https://$JENKINS_USER:$JENKINS_PASS@github.com > /opt/jenkins/.git-credentials\""
    echo "$SERVICE updated"
  done
}

readonly CLUSTERS=$(aws ec2 describe-instances | jq ".Reservations[].Instances[].Tags[] | select(.Key | contains(\"cluster_id\")) | .Value" | sort | uniq | sed 's/\"//g')

for ID in $CLUSTERS; do
  call $ID
done
