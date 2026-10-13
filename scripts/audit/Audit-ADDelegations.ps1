<#
.SYNOPSIS
    Active Directory etki alanındaki Kerberos Yetki Devri (Delegation) yapılandırmalarını denetler.

.DESCRIPTION
    Bu betik etki alanındaki tüm kullanıcı ve bilgisayar nesnelerini tarayarak:
    1. Kısıtlamasız Yetki Devri (Unconstrained Delegation)
    2. Kısıtlı Yetki Devri (Constrained Delegation)
    3. Kaynak Tabanlı Kısıtlı Yetki Devri (Resource-Based Constrained Delegation - RBCD)
    yapılandırmalarını raporlar.

.EXAMPLE
    .\Audit-ADDelegations.ps1
#>

[CmdletBinding()]
param()

Import-Module ActiveDirectory -ErrorAction Stop

Write-Host "=== Active Directory Kerberos Delegasyon Denetimi ===" -ForegroundColor Cyan

# 1. Kısıtlamasız Yetki Devri (Unconstrained Delegation)
Write-Host "`n[+] Kısıtlamasız Yetki Devri Olan Nesneler Taranıyor (DC'ler hariç)..." -ForegroundColor Yellow
$Unconstrained = Get-ADObject -Filter {UserAccountControl -band 0x80000 -and PrimaryGroupID -ne 516} `
  -Properties SamAccountName, ObjectClass, UserAccountControl, OperatingSystem

if ($Unconstrained) {
    $Unconstrained | Select-Object SamAccountName, ObjectClass, OperatingSystem | Format-Table -AutoSize
} else {
    Write-Host "[-] DC haricinde Kısıtlamasız Yetki Devri kullanan nesne bulunamadı (İyi durum)." -ForegroundColor Green
}

# 2. Geleneksel Kısıtlı Yetki Devri (Constrained Delegation)
Write-Host "`n[+] Geleneksel Kısıtlı Yetki Devri (Constrained Delegation) Taranıyor..." -ForegroundColor Yellow
$Constrained = Get-ADObject -Filter 'msDS-AllowedToDelegateTo -like "*"' `
  -Properties SamAccountName, ObjectClass, msDS-AllowedToDelegateTo

if ($Constrained) {
    foreach ($item in $Constrained) {
        [PSCustomObject]@{
            SamAccountName = $item.SamAccountName
            ObjectClass    = $item.ObjectClass
            AllowedSPNs    = ($item.'msDS-AllowedToDelegateTo' -join ', ')
        }
    } | Format-Table -AutoSize
} else {
    Write-Host "[-] Kısıtlı Yetki Devri kullanan nesne bulunamadı." -ForegroundColor Gray
}

# 3. Kaynak Tabanlı Kısıtlı Yetki Devri (RBCD)
Write-Host "`n[+] Kaynak Tabanlı Kısıtlı Yetki Devri (RBCD) Taranıyor..." -ForegroundColor Yellow
$RBCD = Get-ADComputer -Filter 'msDS-AllowedToActOnBehalfOfOtherIdentity -like "*"' `
  -Properties SamAccountName, msDS-AllowedToActOnBehalfOfOtherIdentity

if ($RBCD) {
    foreach ($comp in $RBCD) {
        $sdBytes = $comp.'msDS-AllowedToActOnBehalfOfOtherIdentity'
        $sd = New-Object System.Security.AccessControl.RawSecurityDescriptor($sdBytes, 0)
        [PSCustomObject]@{
            ComputerName = $comp.SamAccountName
            DelegatedToSDDL = $sd.GetSddlForm("All")
        }
    } | Format-Table -AutoSize
} else {
    Write-Host "[-] RBCD yapılandırılmış bilgisayar hesabı bulunamadı." -ForegroundColor Gray
}

Write-Host "`n[+] Denetim tamamlandı." -ForegroundColor Cyan
