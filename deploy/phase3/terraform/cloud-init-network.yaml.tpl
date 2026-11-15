version: 2
# Fixed IP per VM. The network card is found by its MAC address, so its name does not matter.
ethernets:
  nic0:
    match:
      macaddress: "${mac}"
    set-name: eth0
    addresses:
      - ${ip}/24
    routes:
      - to: default
        via: ${gateway}
    nameservers:
      addresses:
        - ${gateway}
        - 1.1.1.1
