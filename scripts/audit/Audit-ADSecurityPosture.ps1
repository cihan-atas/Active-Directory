<#
.SYNOPSIS
    Active Directory etki alanındaki temel güvenlik zafiyeti konfigürasyonlarını tarar.

.DESCRIPTION
    Bu betik:
    1. ms-DS-MachineAccountQuota değerini denetler.
    2. Kerberoasting riski taşıyan kullanıcı hesaplarını (SPN içeren) listeler.
    3. AS-REP Roasting riski taşıyan (DONT_REQ_PREAUTH) hesapları listeler.
    4. KRBTGT hesap parolasının en son ne zaman değiştirildiğini denetler.

.EXAMPLE
    .\Audit-ADSecurityPosture.ps1
#>

[CmdletBinding()]
param()

Import-Module ActiveDirectory -ErrorAction Stop

Write-Host "=== Active Directory Temel Güvenlik Duruşu Denetimi ===" -ForegroundColor Cyan

# 1. MachineAccountQuota
$domain = Get-ADDomain
$maq = $domain.'ms-DS-MachineAccountQuota'
Write-Host "`n[1] ms-DS-MachineAccountQuota Değeri: $maq" -ForegroundColor Yellow
if ($maq -gt 0) {
    Write-Warning "UYARI: MachineAccountQuota $maq olarak ayarlanmış! Sıradan kullanıcılar etki alanına $maq adet makine ekleyebilir (RBCD riski)."
    Write-Host "Öneri: Set-ADDomain -Identity (Get-ADDomain).DistinguishedName -Replace @{'ms-DS-MachineAccountQuota'=0}" -ForegroundColor Gray
} else {
    Write-Host "[+] MachineAccountQuota sıfır (0) olarak ayarlanmış. Güvenli." -ForegroundColor Green
}

# 2. DONT_REQ_PREAUTH (AS-REP Roasting)
Write-Host "`n[2] AS-REP Roasting Açık Hesaplar (DONT_REQ_PREAUTH):" -ForegroundColor Yellow
$asrep = Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true -and Enabled -eq $true} -Properties DoesNotRequirePreAuth
if ($asrep) {
    Write-Warning "UYARI: Aşağıdaki hesaplar parola doğrulama olmaksızın TGT alabilir:"
    $asrep | Select-Object SamAccountName, UserPrincipalName | Format-Table -AutoSize
} else {
    Write-Host "[+] Ön kimlik doğrulama gerektirmeyen (DONT_REQ_PREAUTH) aktif hesap bulunamadı." -ForegroundColor Green
}

# 3. SPN Atanmış Kullanıcı Hesapları (Kerberoasting)
Write-Host "`n[3] SPN Taşıyan Kullanıcı Hesapları (Kerberoasting Hedefleri):" -ForegroundColor Yellow
$kerb = Get-ADUser -Filter {ServicePrincipalName -like "*" -and Enabled -eq $true} -Properties ServicePrincipalName
if ($kerb) {
    $kerb | Select-Object SamAccountName, @{N="SPNs";E={$_.ServicePrincipalName -join ", "}} | Format-Table -AutoSize
} else {
    Write-Host "[-] SPN taşıyan kullanıcı hesabı bulunamadı." -ForegroundColor Gray
}

# 4. KRBTGT Hesap Yaşı
Write-Host "`n[4] KRBTGT Hesap Parola Yaşı:" -ForegroundColor Yellow
$krbtgt = Get-ADUser -Identity "krbtgt" -Properties PasswordLastSet
$daysOld = (New-TimeSpan -Start $krbtgt.PasswordLastSet -End (Get-Date)).Days
Write-Host "krbtgt Parolası Son Değiştirme Tarihi: $($krbtgt.PasswordLastSet) ($daysOld gün önce)" -ForegroundColor White
if ($daysOld -gt 180) {
    Write-Warning "UYARI: krbtgt parolası $daysOld gündür değiştirilmemiş! Düzenli aralıklarla çift sıfırlama önerilir."
} else {
    Write-Host "[+] krbtgt parola yaşı makul seviyede." -ForegroundColor Green
}

Write-Host "`n[+] Güvenlik denetimi tamamlandı." -ForegroundColor Cyan
