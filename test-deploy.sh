#!/bin/bash
REMOTE_HOST=$1

scp -r . $REMOTE_HOST:/tmp/homelab-configurations
ssh $REMOTE_HOST "sudo nixos-rebuild switch --flake '/tmp/homelab-configurations#$REMOTE_HOST'"
ssh $REMOTE_HOST "sudo rm -rf /tmp/homelab-configurations"