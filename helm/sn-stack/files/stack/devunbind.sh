#!/bin/bash
# From esnet-smartnic-fw@5c08736 sn-stack/docker-compose.yml service smartnic-devunbind ($$ unescaped)
set -e -o pipefail -x
# Unbind the kernel driver (if any) from each FPGA PF
dpdk-devbind.py -u $FPGA_PCIE_DEV.0 $FPGA_PCIE_DEV.1
udevadm settle
dpdk-devbind.py --status
# Manually enable device memory since there is no device driver in this mode
setpci -s $FPGA_PCIE_DEV.0 COMMAND=0x2
setpci -s $FPGA_PCIE_DEV.1 COMMAND=0x2
