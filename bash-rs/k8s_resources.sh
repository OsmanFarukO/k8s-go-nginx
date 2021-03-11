#!/bin/bash
# this is a very simple way to show k8s cluster resources

echo ":: Node capacity :: "
kubectl describe nodes | grep -A 6 -e "^\\s*Capacity"

echo ":: Node allocatable capacity ::"
kubectl describe nodes | grep -A 6 -e "^\\s*Allocatable"

echo ":: Node allocated resources :: "
kubectl describe nodes | grep -A 10 -e "^\\s*Allocated resources"

