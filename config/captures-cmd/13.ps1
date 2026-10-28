. D:\tp-kvm\config\captures-cmd\_commun.ps1
# Le mot de passe sudo vient de la variable d'environnement SUDOPW (jamais ecrit dans ce fichier, jamais affiche)
Rocky @("sudo virt-host-validate qemu|||printf '%s\n' '$($env:SUDOPW)' | sudo -S -p '' virt-host-validate qemu")
