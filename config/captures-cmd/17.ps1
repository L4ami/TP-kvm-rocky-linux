. D:\tp-kvm\config\captures-cmd\_commun.ps1
Rocky @('virsh -c qemu:///system domifaddr cirros-test', 'virsh -c qemu:///system net-dhcp-leases default', 'ping -c 4 $(virsh -c qemu:///system domifaddr cirros-test | grep -oE "192\.168\.122\.[0-9]+")')
