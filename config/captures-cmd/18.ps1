. D:\tp-kvm\config\captures-cmd\_commun.ps1
# Le mot de passe CirrOS vient de la variable d'environnement CIRROS_PW (jamais affiche)
Rocky @("virsh console cirros-test|||CIRROS_PW='$($env:CIRROS_PW)' python3 /home/lami/cirros-live.py")
