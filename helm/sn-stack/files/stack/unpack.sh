#!/bin/bash
# From esnet-smartnic-fw@5c08736 sn-stack/docker-compose.yml service smartnic-unpack ($$ unescaped)
set -e -o pipefail -x
rm -f /bitfiles/ok
fw_dir=/usr/local/lib/firmware/esnet-smartnic
for f in ${fw_dir}/esnet-smartnic.{bit,mcs} ; do
  if [ -e ${f}.zst ] ; then
    # input file is compressed, uncompress to output
    unzstd --force --output-dir-flat /bitfiles ${f}.zst
  else
    # input file is not compressed, just copy it to output
    cp -a ${f} /bitfiles
  fi
done

probes=${fw_dir}/debug_nets.ltx
if [ -e ${probes} ]; then
  cp -a ${probes} /bitfiles
else
  # Cleanup leftovers in a pre-existing volume when moving
  # from an FPGA with VIOs to one without them.
  rm -f /bitfiles/$(basename ${probes})
fi

touch /bitfiles/ok
