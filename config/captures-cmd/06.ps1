. D:\tp-kvm\config\captures-cmd\_commun.ps1
Show 'Select-String -Path D:\VMs\kvm-rocky\kvm-rocky.vmx -Pattern "^(displayName|guestOS|firmware|numvcpus|memsize|vhv|nvme0:0.fileName|sata0:[01].fileName|ethernet0.(connectionType|virtualDev))" | ForEach-Object Line'
Show 'Get-ChildItem D:\VMs\kvm-rocky -Filter *.vmdk | Select-Object Name, @{n="Taille_Mo";e={[int]($_.Length/1MB)}}'
