#!/bin/bash

# Set up Prometheus and Grafana on Monitoring Server using Docker
set -e

echo "Setting up Prometheus and Grafana..."

# Create directories
mkdir -p ~/monitoring/prometheus ~/monitoring/grafana

# Create Prometheus configuration file
cat << EOF > ~/monitoring/prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'node_exporter_monitoring'
    static_configs:
      - targets: ['localhost:9100']
  - job_name: 'node_exporter_targets'
    static_configs:
      - targets: ['203.0.113.2:9100', '203.0.113.3:9100']  # Replace with your target EC2 IPs
EOF

# Set permissions
sudo chown -R 472:472 ~/monitoring/grafana  # Grafana user ID
sudo chown -R 65534:65534 ~/monitoring/prometheus  # Prometheus user ID (nobody)

# Create Docker network
docker network create monitoring-network

# Run Prometheus in Docker
docker run -d \
  --name prometheus \
  --network monitoring-network \
  -p 9090:9090 \
  -v ~/monitoring/prometheus:/etc/prometheus \
  --restart always \
  prom/prometheus:latest

# Run Grafana in Docker
docker run -d \
  --name grafana \
  --network monitoring-network \
  -p 3000:3000 \
  -v ~/monitoring/grafana:/var/lib/grafana \
  --restart always \
  grafana/grafana:latest

# Verify containers are running
docker ps

echo "Prometheus and Grafana are running!"
echo "Access Prometheus at http://203.0.113.1:9090"
echo "Access Grafana at http://203.0.113.1:3000 (default login: admin/admin)"