#!/bin/bash
# pcap in -> FPGA ingress path -> pcap out, inside the sn-stack fw container. Nothing leaves the card
# except IN's frames on port 1 (near-end PMA loopback may still transmit them onto port 1's link).
#
#   hw-pcap-test.sh <in.pcap> <expected.pcap> [out.pcap]
#
# Path: pcap -> PF1 -> egress 1 (physical) -> CMAC1 PMA loopback -> ingress P4 -> smartnic_app_igr
# -> P4 dest PF0 -> egress 0 (test) -> PF0 -> pcap. The egress selector index is the port number in
# tdest, so return traffic must use a different index than the transmit side or it loops.
# Must be the only DPDK app on the PFs: testpmd's exit resets the FPGA.
set -u
IN=$1 EXP=$2 OUT=${3:-/tmp/hw_out.pcap}
export REGIO_ESNET_SMARTNIC_PCI_IDS=${REGIO_ESNET_SMARTNIC_PCI_IDS:-0000:c1:00.0}
PCI=${REGIO_ESNET_SMARTNIC_PCI_IDS%.0}

if pgrep -x dpdk-testpmd >/dev/null; then echo "testpmd already running; stop it first" >&2; exit 1; fi
rm -f /tmp/hwt.fifo "$OUT"; mkfifo /tmp/hwt.fifo
setsid nohup sh -c 'exec 3>/tmp/hwt.fifo; exec sleep 600' >/dev/null 2>&1 </dev/null &
# --no-flush-rx: testpmd drains every RX queue on start, which would eat the pcap
setsid nohup dpdk-testpmd -a $PCI.0 -a $PCI.1 -l 1-3 -n 4 --file-prefix c1 \
  --vdev "net_pcap0,rx_pcap=$IN,tx_pcap=$OUT" \
  -- -i --forward-mode=io --port-topology=chained --nb-cores=1 --no-flush-rx \
  </tmp/hwt.fifo >/tmp/hwt.log 2>&1 &
sleep 25

sn-cfg configure host --host-id 0 --reset-dma-queues --dma-queues pf:0:1 >/dev/null
sn-cfg configure host --host-id 1 --reset-dma-queues --dma-queues pf:1:1 >/dev/null
sn-p4 clear table -t forward >/dev/null
for m in 0x000000000000/1 0x800000000000/1; do
  sn-p4 insert table rule -t forward -m $m --action forwardPacket --param 2 --priority 0 >/dev/null || exit 1
done
# PF-bound P4 output skips smartnic_app_igr unless overridden (enable=1, value=0 -> app_igr)
regio-esnet-smartnic eval 'dev0.bar2.app_common.smartnic_app_igr_p4_out_sel = 0x2' >/dev/null
sn-cfg configure switch -i 0:physical:drop -i 1:physical:app -e 0:test -e 1:physical >/dev/null
sn-cfg configure port --port-id 1 --fec reed-solomon --loopback near-end-pma --state enable >/dev/null
sleep 3; sn-cfg clear stats >/dev/null 2>&1

printf 'set portlist 2,1,0\nstart\n' >/tmp/hwt.fifo; sleep 6
sn-cfg configure port --port-id 1 --state disable --loopback none >/dev/null
sn-cfg configure switch -i 1:physical:drop >/dev/null
sn-cfg show switch stats | grep -E 'probe_(to_cmac_1|from_cmac_1|to_app_igr_in1|to_host_0)\.pkt_count'
printf 'stop\nquit\n' >/tmp/hwt.fifo; sleep 8

dump() { tshark -r "$1" -x 2>/dev/null | grep -E '^[0-9a-f]{4}  ' | cut -c1-54; }
if diff <(dump "$OUT") <(dump "$EXP") >/dev/null; then echo "HW_PASS $(capinfos -c "$OUT" | awk '/Number/{print $NF}') frames"
else echo "HW_FAIL"; diff <(dump "$OUT") <(dump "$EXP") | head -20; exit 1; fi
