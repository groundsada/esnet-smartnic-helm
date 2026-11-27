{{- define "sn-stack.fwEnv" }}
- {name: FPGA_PCIE_DEV, value: {{ .Values.fpga.pcieDev | quote }}}
- {name: SN_HW_BOARD, value: {{ .Values.fpga.board | quote }}}
- {name: REGIO_ESNET_SMARTNIC_PCI_IDS, value: "{{ .Values.fpga.pcieDev }}.0"}
{{- end }}
{{- define "sn-stack.priv" }}
securityContext: {privileged: true, runAsUser: 0}
{{- end }}
{{- define "sn-stack.small" }}
resources:
  requests: {cpu: 500m, memory: 512Mi}
  limits: {cpu: "1", memory: 1Gi}
{{- end }}
{{- define "sn-stack.hostdev" }}
volumeMounts:
- {name: dev, mountPath: /dev}
- {name: sys-pci, mountPath: /sys/bus/pci}
- {name: modules, mountPath: /lib/modules, readOnly: true}
- {name: stack-scripts, mountPath: /stack}
{{- end }}
{{- define "sn-stack.server" }}
resources:
  requests: {{ toYaml .Values.resources.server | nindent 4 }}
  limits: {{ toYaml .Values.resources.server | nindent 4 }}
{{- end }}
