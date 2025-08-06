#cloud-config
write_files:
  - path: /etc/systemd/system/k3s-firewall.service
    permissions: "0644"
    content: |
      [Unit]
      Description=Configure firewall for K3s
      After=firewalld.service
      Wants=network-online.target
      After=network-online.target

      [Service]
      Type=oneshot
      RemainAfterExit=yes
      ExecStart=/usr/bin/firewall-cmd --permanent --add-port=6443/tcp
      ExecStart=/usr/bin/firewall-cmd --permanent --add-port=2379/tcp
      ExecStart=/usr/bin/firewall-cmd --permanent --add-port=2380/tcp
      ExecStart=/usr/bin/firewall-cmd --reload

      [Install]
      WantedBy=multi-user.target

runcmd:
  - swapoff -a
  - sed -i.bak '/ swap / s/^/#/' /etc/fstab
  - sudo systemctl enable firewalld
  - sudo systemctl start firewalld
  - sudo systemctl daemon-reload
  - sudo systemctl enable k3s-firewall.service
  - sudo systemctl start k3s-firewall.service
  - curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --cluster-init --tls-san ${k3s_api_dns}.${domain} --disable traefik --disable metrics-server --disable servicelb --flannel-backend=host-gw" sh - | tee /var/log/k3s-install.log
