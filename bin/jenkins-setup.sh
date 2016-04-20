#!/bin/bash

args=("$@")

JENKINS_USER=${args[0]}
JENKINS_EMAIL=${args[1]}
JENKINS_PASS=${args[2]}

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

CLUSTERS=$(aws ec2 describe-instances | jq ".Reservations[].Instances[].Tags[] | select(.Key | contains(\"cluster_id\")) | .Value" | sort | uniq | sed 's/\"//g')

for CLUSTER_ID in $CLUSTERS; do

  printf '\n'
  echo "Cluster $CLUSTER_ID"
  printf '%32s\n' | tr ' ' =

  IP=$(aws ec2 describe-instances --filter Name=tag:cluster_id,Values=$CLUSTER_ID | jq '.Reservations[].Instances[].PublicIpAddress' | head -n 1 | sed 's/\"//g')

  TUNNEL="FLEETCTL_TUNNEL=$IP"

  SERVICES=$(env $TUNNEL fleetctl list-units | cut -d'.' -f1 | awk 'NR>1' | grep jenkins@)

  for SERVICE in $SERVICES; do
    DOCKER=$(echo $SERVICE | tr '@' '-')
    env $TUNNEL fleetctl ssh $SERVICE "docker exec $DOCKER git config --global user.name $JENKINS_USER"
    env $TUNNEL fleetctl ssh $SERVICE "docker exec $DOCKER git config --global user.email $JENKINS_EMAIL"
    env $TUNNEL fleetctl ssh $SERVICE "docker exec $DOCKER echo https://$JENKINS_USER:$JENKINS_PASS@github.com > .git-credentials"
    echo "Done"
  done
done
