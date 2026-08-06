cmd_/userdata/AI_NPU/driver/pango_pci_driver.mod := printf '%s\n'   pango_pci_driver.o | awk '!x[$$0]++ { print("/userdata/AI_NPU/driver/"$$0) }' > /userdata/AI_NPU/driver/pango_pci_driver.mod
