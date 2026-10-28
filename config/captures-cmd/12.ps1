. D:\tp-kvm\config\captures-cmd\_commun.ps1
Rocky @('systemctl status virtqemud --no-pager -n 0', 'systemctl is-enabled virtqemud.socket virtnetworkd.socket', 'ls -l /dev/kvm', 'lsmod | grep kvm', "grep -cE 'vmx|svm' /proc/cpuinfo")
