#!/bin/bash
# Emit the sn-vm cloud-init Secret: key auth for ubuntu (~/.ssh/kubevirt.pub) plus a password
# for `virtctl console` / ssh password auth. The password is kept in ./sn-vm.password (mode 600).
set -e -o pipefail
cd "$(dirname "$0")"
PUB=${PUB:-$HOME/.ssh/kubevirt.pub}
[ -s sn-vm.password ] || (umask 077; openssl rand -base64 18 > sn-vm.password)
PW=$(cat sn-vm.password)

USERDATA=$(cat <<EOF
#cloud-config
hostname: sn-vm
ssh_pwauth: true
users:
  - name: ubuntu
    groups: [sudo, docker]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    ssh_authorized_keys:
      - $(cat "$PUB")
chpasswd:
  expire: false
  users:
    - {name: ubuntu, password: "$PW", type: text}
# Ubuntu 24.04 cloud images ship 60-cloudimg-settings.conf with PasswordAuthentication no,
# which wins over ssh_pwauth on some images. Force it.
write_files:
  - path: /etc/ssh/sshd_config.d/00-pwauth.conf
    content: "PasswordAuthentication yes\nKbdInteractiveAuthentication yes\n"
package_update: true
packages: [qemu-guest-agent, docker.io, docker-compose-v2, pciutils, usbutils, git, unzip]
runcmd:
  - systemctl enable --now qemu-guest-agent
  - systemctl restart ssh
  - usermod -aG docker ubuntu
EOF
)

kubectl create secret generic sn-vm-cloudinit --from-literal=userdata="$USERDATA" --dry-run=client -o yaml
