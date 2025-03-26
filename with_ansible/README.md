
---

# Ansible Setup for Prometheus and Grafana Monitoring on AWS EC2 Instances


## Tools:

- **Prometheus**: Collects and stores metrics.
- **Node Exporter**: Exposes system metrics from each EC2 instance.
- **Grafana**: Visualizes metrics in dashboards.
- **Docker**: Simplifies deployment and management.
- **Ansible**: Configuration management
- **Environment**: Ubuntu 22.04 on AWS EC2.

## Visualization

![image](https://github.com/user-attachments/assets/f9301eb2-857b-45c9-a621-81deacd5311f)


## Prerequisites

- **AWS EC2 Instances:**
  - At least 2 Ubuntu 22.04 instances:
    - Monitoring server: `t2.medium` (e.g., public IP `52.200.27.51`).
    - Target instances: `t2.micro` (e.g., public IPs `54.159.53.106`, `54.81.204.21`).
- **Security Groups:**
  - Monitoring Server:
    - Allow inbound: 3000 (Grafana), 9090 (Prometheus), 9100 (Node Exporter), 22 (SSH).
    - Source: `0.0.0.0/0` (or restrict to your IP).
  - Target Instances:
    - Allow inbound: 9100 (Node Exporter), 22 (SSH).
    - Source: Monitoring server’s security group (or its public IP).
- **Ansible Controller:**
  - Ubuntu WSL (Windows Subsystem for Linux) with Ubuntu 22.04.
  - SSH key pair for accessing EC2 instances.

## Procedure 1: Set Up Ansible on Ubuntu WSL (Ansible Controller)

1. **Install Ansible:**
   ```bash
   sudo apt update && sudo apt upgrade -y
   sudo apt install -y ansible
   ```

2. **Verify Ansible Installation:**
   ```bash
   ansible --version
   ```

3. **Set Up SSH Key for EC2 Access:**
   ```bash
   cp /path/to/your-key.pem ~/.ssh/
   chmod 400 ~/.ssh/your-key.pem
   ssh-keyscan -H 52.200.27.51 >> ~/.ssh/known_hosts
   ssh-keyscan -H 54.159.53.106 >> ~/.ssh/known_hosts
   ssh-keyscan -H 54.81.204.21 >> ~/.ssh/known_hosts
   ```

## Procedure 2: Create Ansible Inventory File

1. **Create Inventory File:**
   ```bash
   vi ~/inventory.ini
   ```
   Add:
   ```ini
   [monitoring]
   52.200.27.51 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/your-key.pem

   [targets]
   54.159.53.106 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/your-key.pem
   54.81.204.21 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/your-key.pem
   ```

![image](https://github.com/user-attachments/assets/fa624660-4076-4350-aa50-56946a94e75e)


2. **Test Connectivity:**
   ```bash
   ansible all -i ~/inventory.ini -m ping
   ```

![image](https://github.com/user-attachments/assets/b549f42f-d1bb-4748-8fa5-5eda1d184c76)


## Procedure 3: Create and Run Ansible Playbook

### Playbook: `setup_monitoring.yml`

```yaml
---
- name: Set up Prometheus, Grafana, and Node Exporter on EC2 instances
  hosts: all
  become: yes
  tasks:
    - name: Update system packages
      apt:
        update_cache: yes
        upgrade: dist

    - name: Install prerequisites for Docker
      apt:
        name:
          - apt-transport-https
          - ca-certificates
          - curl
          - software-properties-common
        state: present

    - name: Add Docker GPG key
      ansible.builtin.shell: |
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
      args:
        creates: /usr/share/keyrings/docker-archive-keyring.gpg

    - name: Add Docker repository
      ansible.builtin.shell: |
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
      args:
        creates: /etc/apt/sources.list.d/docker.list

    - name: Install Docker
      apt:
        update_cache: yes
        name:
          - docker-ce
          - docker-ce-cli
          - containerd.io
        state: present

    - name: Start and enable Docker
      systemd:
        name: docker
        state: started
        enabled: yes

    - name: Add ubuntu user to docker group
      user:
        name: ubuntu
        groups: docker
        append: yes

    - name: Run Node Exporter container
      docker_container:
        name: node_exporter
        image: prom/node-exporter:latest
        state: started
        restart_policy: always
        ports:
          - "9100:9100"

- name: Set up Prometheus and Grafana on monitoring server
  hosts: monitoring
  become: yes
  tasks:
    - name: Create directories for Prometheus and Grafana
      file:
        path: "{{ item }}"
        state: directory
        owner: "{{ (item == '/home/ubuntu/monitoring/prometheus') | ternary(65534, 472) }}"
        group: "{{ (item == '/home/ubuntu/monitoring/prometheus') | ternary(65534, 472) }}"
      loop:
        - /home/ubuntu/monitoring/prometheus
        - /home/ubuntu/monitoring/grafana

    - name: Create Prometheus configuration file
      copy:
        content: |
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
                - targets: ['54.159.53.106:9100', '54.81.204.21:9100']
        dest: /home/ubuntu/monitoring/prometheus/prometheus.yml
        owner: 65534
        group: 65534

    - name: Create Docker network
      docker_network:
        name: monitoring-network
        state: present

    - name: Run Prometheus container
      docker_container:
        name: prometheus
        image: prom/prometheus:latest
        state: started
        restart_policy: always
        networks:
          - name: monitoring-network
        ports:
          - "9090:9090"
        volumes:
          - /home/ubuntu/monitoring/prometheus:/etc/prometheus

    - name: Run Grafana container
      docker_container:
        name: grafana
        image: grafana/grafana:latest
        state: started
        restart_policy: always
        networks:
          - name: monitoring-network
        ports:
          - "3000:3000"
        volumes:
          - /home/ubuntu/monitoring/grafana:/var/lib/grafana
        env:
          GF_SECURITY_ADMIN_PASSWORD: "yournewpassword"
```

### Steps to Run

1. **Create the Playbook:**
   ```bash
   nano ~/setup_monitoring.yml
   ```
   - Paste the playbook content, save, and exit.

2. **Update the Playbook:**
   - Replace `54.159.53.106:9100` and `54.81.204.21:9100` with the public IPs of your target EC2 instances.
   - Update `GF_SECURITY_ADMIN_PASSWORD` to a secure password for Grafana.

3. **Run the Playbook:**
   ```bash
   ansible-playbook -i ~/inventory.ini ~/setup_monitoring.yml
   ```

![image](https://github.com/user-attachments/assets/52958091-5372-4a08-98d2-f095a99b2ba4)


## Procedure 4: Configure Grafana Dashboard

1. **Access Grafana:**
   - Open `http://52.200.27.51:3000`.
   - Log in with username `admin` and password `yournewpassword`.

2. **Add Prometheus Data Source:**
   - Left sidebar: **Connections** > **Data sources**.
   - Click **Add data source** > Select **Prometheus**.
   - **Name:** `Prometheus`.
   - **URL:** `http://prometheus:9090`.
   - Click **Save & Test**.

3. **Create a Dashboard:**
   - Left sidebar: **Dashboards** > **New** > **Create dashboard**.
   - Click **Add visualization**.
   - **CPU Usage Panel:**
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

4. **Import a Pre-Built Dashboard:**
   - Go to **Dashboards** > **New** > **Import**.
   - Use ID `1860` (Node Exporter Full Dashboard) from grafana.com.
   - Select your Prometheus data source and import.
  
   ![image](https://github.com/user-attachments/assets/0226cbd0-2c70-424b-8c60-396c6621b401)


## Procedure 5: Verify the Setup

1. **Verify Prometheus Targets:**
   - Open `http://52.200.27.51:9090/targets`.
   - Ensure all targets (`localhost:9090`, `localhost:9100`, `54.159.53.106:9100`, `54.81.204.21:9100`) are “UP”.
  
  ![image](https://github.com/user-attachments/assets/edefbabf-abdb-4070-8736-3e2127847315)


2. **Verify Grafana Dashboard:**
   - Open `http://52.200.27.51:3000`.
   - Check your “Multi-EC2 Monitoring” dashboard for metrics from all instances.

3. **Verify Node Exporter Metrics:**
   - On each target instance:
     ```bash
     ssh -i ~/.ssh/your-key.pem ubuntu@54.159.53.106
     curl http://localhost:9100/metrics
     ```

  ![image](https://github.com/user-attachments/assets/a0eba6df-0108-4df6-b024-376f9bdbb5bc)


## Procedure 6: Secure the Setup

1. **Restrict Security Groups:**
   - Update the monitoring server’s security group:
     - Port 3000 (Grafana): Allow only your IP.
     - Port 9090 (Prometheus): Allow only your IP.
     - Port 9100 (Node Exporter): Allow only the monitoring server’s IP.

---
