# esnet-smartnic-helm

The ESnet SmartNIC stack (`esnet-smartnic-fw`'s docker compose `sn-stack`) on an NRP (Nautilus)
node with an AMD Alveo U55C, as a Helm chart. One release drives one card.

- `helm/sn-stack/`: the chart (default path). One privileged pod pinned to the node:
  - init containers: unpack, hw_server (native sidecar), JTAG program, PF bind;
  - `vfio-unlock` sidecar: keeps the PFs in D0 under vfio-pci (otherwise registers read `0xffffffff`);
  - containers: `sn-cfg` server, `sn-p4` server (optional), tools.
  - `flash.enabled=true` runs a Job that writes the `.mcs` to the card's QSPI user partition.
- `kubevirt/`: a KubeVirt VM alternative (not deployed).

## Install

```bash
kubectl -n esnet-fpga-experiments create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io --docker-username=<user> --docker-password=<read:packages PAT>
helm upgrade --install sn helm/sn-stack -n esnet-fpga-experiments --reset-values \
  --set images.fw=ghcr.io/groundsada/smartnic-nrp-images/esnet-smartnic-fw:<tag> \
  --set p4.enabled=true
```

Always pass `--reset-values`: Helm 4 otherwise reuses earlier `--set` values (for example a
leftover `flash.enabled=true`).

Programming (`program.enabled`) and flashing (`flash.enabled`) replace what runs on the card and
are off by default. The fw image must be built from the same ESnet hw/fw commit pair as the
bitstream it carries (address map and regmap must match).

## Wiring on node-2-11 (U55C at `c1:00`)

- Port 1 (QSFP28 SR4) goes straight to the node's Mellanox `enp65s0f0np0`, a private FPGA-to-host
  wire. LLDP from the node arrives on it.
- Port 0 (QSFP28 DR) goes to a lab switch.

Ports come up `disable`d, the packet switch's ingress selectors default to `drop`, and every FPGA
reset puts p4_only's table back to `loopPacket`. So install P4 rules before
`sn-cfg configure switch -i <port>:physical:app`. For example, send everything to the host:

```bash
sn-p4 insert table rule -t forward -m 0x000000000000/1 --action forwardPacket --param 2 --priority 0
sn-p4 insert table rule -t forward -m 0x800000000000/1 --action forwardPacket --param 2 --priority 0
sn-cfg configure switch -i 1:physical:app
sn-cfg configure port --port-id 1 --fec reed-solomon --state enable
dpdk-dumpcap --file-prefix c1 -i 1 -w /tmp/p1.pcapng -a duration:60
```
