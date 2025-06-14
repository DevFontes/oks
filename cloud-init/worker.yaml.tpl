#cloud-config
runcmd:
  - swapoff -a
  - sed -i.bak '/ swap / s/^/#/' /etc/fstab
  - until curl -skf https://${server_ip}:6443/ping; do sleep 5; done
  - curl -sfL https://get.k3s.io | K3S_URL="https://${server_ip}:6443" K3S_TOKEN="${k3s_token}" sh - | tee /var/log/k3s-worker-install.log