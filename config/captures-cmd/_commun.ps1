# Fonctions communes aux scripts de capture.
$KEY = "$env:USERPROFILE\.ssh\kvm_rocky_key"
$IP  = "192.168.190.145"
# Affiche l'invite PowerShell + la commande, puis l'execute
function Show([string]$cmd) { Write-Host -NoNewline 'PS D:\tp-kvm> '; Write-Host $cmd; Invoke-Expression $cmd; Write-Host '' }
# Ouvre une connexion SSH vers kvm-rocky et lance les commandes en affichant l'invite Linux avant chacune.
# Une entree "affiche|||reelle" permet d'afficher une commande sudo sans montrer le mot de passe envoye a sudo -S.
function Rocky([string[]]$cmds) {
  Write-Host -NoNewline 'PS D:\tp-kvm> '; Write-Host "ssh -i `$env:USERPROFILE\.ssh\kvm_rocky_key lami@$IP"
  $parts = foreach ($c in $cmds) {
    $aff, $reel = $c -split '\|\|\|'; if (-not $reel) { $reel = $aff }
    "printf '\033[1;32m[lami@kvm-rocky ~]`$\033[0m %s\n' '" + ($aff -replace "'","'\''") + "'; " + $reel + "; echo"
  }
  ssh -t -o LogLevel=ERROR -i $KEY lami@$IP ($parts -join '; ') 2>$null
}
