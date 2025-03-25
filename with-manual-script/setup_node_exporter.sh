#!/bin/bash

# Install and Run Node Exporter on Target EC2 Instance
set -e

echo "Setting up Node Exporter on Target Instance..."

# Run Node Exporter in Docker
docker run -d \
  --name node_exporter \
  -p 9100:9100 \
  --restart always \
  prom/node-exporter:latest

# Verify Node Exporter
curl http://localhost:9100/metrics

echo "Node Exporter is running on port 9100!"