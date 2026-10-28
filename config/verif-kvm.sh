#!/bin/bash
# Verifications du TP KVM, lancees sur kvm-rocky. Chaque commande est affichee avant sa sortie.
# Le mot de passe sudo est passe par la variable SUDOPW (jamais ecrit dans ce fichier).
run() { echo "[lami@kvm-rocky ~]\$ $*"; eval "$@" 2>&1; echo; }
sudo_run() { echo "[lami@kvm-rocky ~]\$ sudo $*"; printf '%s\n' "$SUDOPW" | sudo -S -p "" "$@" 2>&1; echo; }
run cat /etc/rocky-release
run dnf group list --installed
run rpm -q qemu-kvm libvirt virt-install
run systemctl status virtqemud --no-pager
run "lsmod | grep kvm"
run "grep -cE 'vmx|svm' /proc/cpuinfo"
sudo_run virt-host-validate qemu
run virsh -c qemu:///system list --all
run virsh -c qemu:///system net-list --all
