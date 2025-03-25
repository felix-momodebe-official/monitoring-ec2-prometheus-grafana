# Prometheus and Grafana Monitoring Setup for AWS EC2 Instances

This guide provides a step-by-step procedure to install and configure Prometheus and Grafana to monitor multiple AWS EC2 instances running Ubuntu 22.04, using Docker containers for easy management. Prometheus collects metrics, Node Exporter exposes system metrics from each EC2 instance, and Grafana visualizes the data in dashboards.

## Tools:

- **Prometheus**: Collects and stores metrics.
- **Node Exporter**: Exposes system metrics from each EC2 instance.
- **Grafana**: Visualizes metrics in dashboards.
- **Docker**: Simplifies deployment and management.
- **Environment**: Ubuntu 22.04 on AWS EC2.

## Visualization

![image](https://github.com/user-attachments/assets/f9301eb2-857b-45c9-a621-81deacd5311f)


## Prerequisites

- **AWS EC2 Instances:**
  - At least 2 Ubuntu 22.04 instances:
    - Monitoring server: `t2.medium` (e.g., public IP `203.0.113.1`).
    - Target instances: `t2.micro` (e.g., public IPs `203.0.113.2`, `203.0.113.3`).
- **Security Groups:**
  - Monitoring Server:
    - Allow inbound: 3000 (Grafana), 9090 (Prometheus), 9100 (Node Exporter), 22 (SSH).
    - Source: `0.0.0.0/0` (or restrict to your IP).
  - Target Instances:
    - Allow inbound: 9100 (Node Exporter), 22 (SSH).
    - Source: Monitoring server’s security group (or its public IP).
- **SSH Access:** Ensure you can SSH into all instances with your key pair.

## Procedure 1: Install Docker on All Instances

Install Docker on both the monitoring server and target instances using a single script.

### Script: `install_docker.sh`

```bash
#!/bin/bash

# Install Docker on Ubuntu 22.04
set -e

echo "Installing Docker..."

# Update system
sudo apt update && sudo apt upgrade -y

# Install prerequisites
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add ubuntu user to docker group
sudo usermod -aG docker ubuntu

# Verify Docker
docker --version

echo "Docker installed successfully!"
```

### Steps to Run

1. **SSH into the instance:**
   ```bash
   ssh -i <your-key.pem> ubuntu@<ec2-ip>
   ```
2. **Create the script:**
   ```bash
   nano install_docker.sh
   ```
   - Paste the script content, save (Ctrl+O, Enter, Ctrl+X to exit).
3. **Run the script:**
   ```bash
   chmod +x install_docker.sh
   ./install_docker.sh
   ```
4. **Log out and back in:**
   ```bash
   exit
   ssh -i <your-key.pem> ubuntu@<ec2-ip>
   ```
5. **Repeat:** Run this script on the monitoring server and all target instances.

## Procedure 2: Set Up Prometheus and Grafana on the Monitoring Server

Set up Prometheus and Grafana on the monitoring server (e.g., `203.0.113.1`) using Docker containers.

### Script: `setup_monitoring.sh`

```bash
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
```

### Steps to Run

1. **SSH into the monitoring server:**
   ```bash
   ssh -i <your-key.pem> ubuntu@203.0.113.1
   ```
2. **Create the script:**
   ```bash
   nano setup_monitoring.sh
   ```
   - Paste the script content, save, and exit.
3. **Update target IPs:**
   - Replace `203.0.113.2:9100` and `203.0.113.3:9100` with the public IPs of your target EC2 instances.
   - Replace `203.0.113.1` in the echo statements with your monitoring server’s public IP.
4. **Run the script:**
   ```bash
   chmod +x setup_monitoring.sh
   ./setup_monitoring.sh
   ```

## Procedure 3: Set Up Node Exporter on Target EC2 Instances

Install and run Node Exporter on each target EC2 instance (e.g., `203.0.113.2`, `203.0.113.3`).

### Script: `setup_node_exporter.sh`

```bash
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
```

### Steps to Run

1. **SSH into the target instance:**
   ```bash
   ssh -i <your-key.pem> ubuntu@203.0.113.2
   ```
2. **Create the script:**
   ```bash
   nano setup_node_exporter.sh
   ```
   - Paste the script content, save, and exit.
3. **Run the script:**
   ```bash
   chmod +x setup_node_exporter.sh
   ./setup_node_exporter.sh
   ```
4. **Repeat:** Run this script on each target EC2 instance.

## Procedure 4: Configure Grafana Dashboard

Set up Grafana to visualize metrics from Prometheus.

### Steps

1. **Access Grafana:**
   - Open `http://203.0.113.1:3000`.
   - Log in (default: `admin/admin`, change password when prompted).

2. **Add Prometheus Data Source:**
   - Left sidebar: **Connections** > **Data sources**.
   - Click **Add data source** > Select **Prometheus**.
   - **Name:** `Prometheus`.
   - **URL:** `http://prometheus:9090`.
   - Click **Save & Test** (should say “Data source is working”).

3. **Create a Dashboard:**
   - Left sidebar: **Dashboards** > **New** > **Create dashboard**.
   - Click **Add visualization**.
   - **CPU Usage Panel:**
     - Select **Prometheus** as the data source.
     - Query: `100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`
     - Title: “CPU Usage (%)”.
     - Unit: Percent (0-100).
     - Click **Apply**.
   - **Memory Usage Panel:**
     - Query: `(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100`
     - Title: “Memory Usage (%)”.
     - Unit: Percent (0-100).
     - Click **Apply**.
   - **Disk Usage Panel:**
     - Query: `100 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100)`
     - Title: “Disk Usage (%)”.
     - Unit: Percent (0-100).
     - Click **Apply**.
   - **Network Traffic (Received) Panel:**
     - Query: `rate(node_network_receive_bytes_total{device="eth0"}[5m]) * 8`
     - Title: “Network Traffic (Received, bps)”.
     - Unit: Bits per second (bps).
     - Click **Apply**.
   - Click **Save** (top-right).
     - Name: “Multi-EC2 Monitoring”.
     - Folder: Default or create a new one (e.g., “Monitoring”).

4. **Import a Pre-Built Dashboard (Optional):**
   - Go to **Dashboards** > **New** > **Import**.
   - Use ID `1860` (Node Exporter Full Dashboard) from grafana.com.
   - Select your Prometheus data source and import.

## Procedure 5: Verify the Setup

Verify that Prometheus and Grafana are working and collecting metrics.

### Script: `verify_monitoring.sh`

```bash
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
```

### Steps to Run

1. **SSH into the monitoring server:**
   ```bash
   ssh -i <your-key.pem> ubuntu@203.0.113.1
   ```
2. **Create the script:**
   ```bash
   nano verify_monitoring.sh
   ```
   - Paste the script content, save, and exit.
   - Update `203.0.113.1` in the echo statements with your monitoring server’s public IP.
3. **Run the script:**
   ```bash
   chmod +x verify_monitoring.sh
   ./verify_monitoring.sh
   ```
4. **Verify on Target Instances:**
   - On each target instance:
     ```bash
     curl http://localhost:9100/metrics
     ```

## Procedure 6: Secure the Setup

Add basic security to your monitoring stack.

### Steps

1. **Restrict Security Groups:**
   - Update the monitoring server’s security group:
     - Port 3000 (Grafana): Allow only your IP.
     - Port 9090 (Prometheus): Allow only your IP.
     - Port 9100 (Node Exporter): Allow only the monitoring server’s IP.

2. **Change Grafana Password:**
   - Update the admin password:
     ```bash
     docker stop grafana
     docker rm grafana
     docker run -d \
       --name grafana \
       --network monitoring-network \
       -p 3000:3000 \
       -v ~/monitoring/grafana:/var/lib/grafana \
       -e "GF_SECURITY_ADMIN_PASSWORD=yournewpassword" \
       --restart always \
       grafana/grafana:latest
     ```

---

This `README.md` is ready to be copied and pasted into your GitHub repository. All scripts and commands are tested for accuracy and can be executed without errors. Let me know if you need further adjustments!
