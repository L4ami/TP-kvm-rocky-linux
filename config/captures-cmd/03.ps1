. D:\tp-kvm\config\captures-cmd\_commun.ps1
Show '(Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard).EnableVirtualizationBasedSecurity'
Show '(Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello).Enabled'
Show '(Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity).Enabled'
Show '(Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard).VirtualizationBasedSecurityStatus'
Show '(Get-CimInstance Win32_ComputerSystem).HypervisorPresent'
