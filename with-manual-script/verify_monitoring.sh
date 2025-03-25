#!/bin/bash

# Verify Prometheus, Grafana, and Node Exporter setup
set -e

echo "Checking Prometheus..."
curl http://localhost:9090

echo "Checking Prometheus targets..."
curl http://localhost:9090/api/v1/targets

echo "Checking Node Exporter on monitoring server..."
curl http://localhost:9100/metrics

echo "Checking Docker containers..."
docker ps

echo "Verification complete!"
echo "Access Prometheus at http://203.0.113.1:9090"
echo "Access Grafana at http://203.0.113.1:3000"