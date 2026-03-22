#!/bin/bash
set -euo pipefail

echo 'Configuring SSH'

cat > /etc/ssh/sshd_config.d/hardening.conf << 'EOF'
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
AuthenticationMethods publickey
AllowUsers fragmented-agent
UseDNS no
X11Forwarding no
ClientAliveInterval 60
ClientAliveCountMax 3
EOF

echo 'Setting up pub-key'

mkdir -p /home/fragmented-agent/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJDFEb1hybmPSSGHZTE11grwYHZjg0gVgJMYu3Z8atio fragmented-agent' > /home/fragmented-agent/.ssh/authorized_keys
chown -R fragmented-agent:fragmented-agent /home/fragmented-agent/.ssh
chmod 700 /home/fragmented-agent/.ssh
chmod 600 /home/fragmented-agent/.ssh/authorized_keys

echo 'Configuring sudo access for fragmented-agent user'

usermod -aG sudo fragmented-agent
echo 'fragmented-agent ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/fragmented-agent
chmod 440 /etc/sudoers.d/fragmented-agent

echo 'Running system upgrade'

apt-get update -qq
apt-get dist-upgrade -y
apt-get autoremove -y
apt-get clean

echo 'Post-installation completed.'
