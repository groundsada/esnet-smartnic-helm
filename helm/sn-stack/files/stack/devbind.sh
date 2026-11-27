#!/bin/bash
# From esnet-smartnic-fw@5c08736 sn-stack/docker-compose.yml service smartnic-devbind ($$ unescaped)
set -e -o pipefail -x
# When vfio-pci is not builtin, ensure that it is loaded
modinfo vfio-pci | egrep -q '^filename:\s+\(builtin\)$' || modprobe vfio-pci
# Bind the vfio-pci driver to each FPGA PF
dpdk-devbind.py -b vfio-pci $FPGA_PCIE_DEV.0 $FPGA_PCIE_DEV.1
udevadm settle
dpdk-devbind.py --status
# Confirm that the driver is properly bound to each FPGA PF
# Note the <TAB> before vfio-pci in the grep command
lspci -D -kvm -s $FPGA_PCIE_DEV.0 | grep '^Driver:	vfio-pci'
lspci -D -kvm -s $FPGA_PCIE_DEV.1 | grep '^Driver:	vfio-pci'
