#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Active Directory Vault — Tam Kapsamlı Doküman ve Cephanelik Komut Çıkarıcısı (Universal Extractor) v4
Bu betik projedeki TÜM 267 Markdown dokümanını (Modül 11 Araçları, Red Team Taktikleri,
Blue Team Tehdit Avı ve Sistem Yöneticisi Kılavuzları) tarayarak:
1. Section 2 (Temel Sözdizimi)
2. Section 3 (Pratik Senaryo ve Kullanım Komutları)
3. Section 4 / 5 (Tespit, Tehdit Avı ve Olay Günlüğü Komutları)
4. Section 6 (Cheat Sheet / Hızlı Referans Komutları)
bölümlerindeki TÜM çalıştırılabilir operasyonel komutları çıkarır.
Sonuç: 3,300+ komuttan oluşan devasa, tam kapsamlı ve canlı derlenebilir Active Directory Cephaneliği!
Çıktı: app/assets/data/commands_catalog.json
"""

import os
import re
import json
import glob
import hashlib
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
OUTPUT_FILE = BASE_DIR / "app" / "assets" / "data" / "commands_catalog.json"

# Ortak hedef / bağlam yer tutucu kalıpları
DOMAIN_PATTERNS = [
    r'\bcorp\.local\b', r'\bdomain\.local\b', r'\binlanefreight\.local\b',
    r'\bcontoso\.com\b', r'\blab\.local\b', r'\btarget\.local\b', r'\bhtb\.local\b',
    r'\bsirket\.local\b', r'\bexample\.com\b'
]

DC_IP_PATTERNS = [
    r'192\.168\.1\.10', r'10\.10\.10\.10', r'172\.16\.5\.5', r'10\.10\.10\.5', r'10\.10\.10\.1'
]

TARGET_IP_PATTERNS = [
    r'192\.168\.1\.20', r'10\.10\.10\.20', r'172\.16\.5\.20', r'10\.10\.10\.100',
    r'192\.168\.1\.50', r'198\.51\.100\.10', r'192\.168\.1\.15'
]

USER_PATTERNS = [
    r'\bjdoe\b', r'\bsvc_web\b', r'\bsvc_sql\b', r'\bsvc_backup\b', r'\bsvc_admin\b',
    r'\bj\.doe\b', r'\bahmet\b', r'\bmehmet\b', r'\bAdministrator\b'
]

PASS_PATTERNS = [
    r'Password123!', r'Welcome123!', r'Summer2024!', r'Spring2026!', r'Pass123!',
    r'Password123', r'P@ssw0rd123!', r'P@ssw0rd123', r'AdminPass!', r'SuperSecret!',
    r'Sifre123', r'Parola123', r'Sonbahar2026!'
]

HASH_PATTERNS = [
    r'01fc5a6be7bc6929c40372d23f5052b3',
    r'aad3b435b51404eeaad3b435b51404ee:e19ccf7504d36cedc34e212d4e6547e0',
    r'e19ccf7504d36cedc34e212d4e6547e0',
    r'2b576ac7403010bc851004f0635ff54e',
    r'31d6cfe0d16ae931b73c59d7e0c089c0',
    r'51a26b735c02dcda234b21651d30f7b1'
]

POWERSHELL_OPERATORS = {
    '-eq', '-ne', '-gt', '-lt', '-ge', '-le', '-like', '-notlike', '-match', '-notmatch',
    '-contains', '-notcontains', '-in', '-notin', '-replace', '-split', '-join', '-is',
    '-isnot', '-as', '-and', '-or', '-not', '-band', '-bor', '-bxor', '-bnot', '-shl', '-shr'
}

COMMON_AD_FLAGS = {
    "-u": "Hedef veya etki alanı kullanıcı adı",
    "--user": "Hedef veya etki alanı kullanıcı adı",
    "-p": "Kullanıcı açık metin parolası",
    "--password": "Kullanıcı açık metin parolası",
    "-d": "Hedef etki alanı adı (FQDN veya NetBIOS)",
    "--domain": "Hedef etki alanı adı (FQDN veya NetBIOS)",
    "-H": "Pass-the-Hash için NTLM özeti (LM:NT veya :NT)",
    "--hash": "Pass-the-Hash için NTLM özeti (LM:NT veya :NT)",
    "--hashes": "Pass-the-Hash için NTLM özeti (LM:NT veya :NT)",
    "-dc-ip": "Etki Alanı Denetleyicisinin (DC) IP adresi",
    "--dc-ip": "Etki Alanı Denetleyicisinin (DC) IP adresi",
    "-target-ip": "Hedef sistem IP adresi",
    "-t": "Hedef IP adresi veya taranacak aralık",
    "--target": "Hedef sistem IP adresi veya FQDN",
    "-k": "Kerberos kimlik doğrulaması kullan (KRB5CCNAME)",
    "--kerberos": "Kerberos kimlik doğrulaması kullan (KRB5CCNAME)",
    "-no-pass": "Parola girmeden kimlik doğrulama dene (boş oturum / Kerberos)",
    "--no-pass": "Parola girmeden kimlik doğrulama dene (boş oturum / Kerberos)",
    "--local-auth": "Etki alanı yerine hedef makinenin yerel SAM veritabanını sorgula",
    "--sam": "Yerel SAM veritabanındaki NTLM hash'lerini dök",
    "--lsa": "LSA Secrets (servis hesapları, DPAPI) dökümünü al",
    "--ntds": "Active Directory NTDS.dit veritabanından parola özetlerini çek",
    "--laps": "Active Directory'den LAPS yerel yönetici parolalarını çek",
    "--shares": "SMB ağ paylaşımlarını ve okuma/yazma izinlerini listele",
    "-A": "Tüm bilgi toplama ve numaralandırma modüllerini sırayla çalıştır",
    "-U": "Etki alanı veya yerel kullanıcı hesaplarını listele",
    "-G": "Grupları ve grup üyeliklerini listele",
    "-P": "Etki alanı parola ve hesap kilitleme politikasını getir",
    "-S": "Ağ paylaşımlarını listele",
    "-C": "Paylaşımların yazılabilirliğini test et",
    "-R": "Belirtilen aralıkta RID döngüsü (RID cycling) ile hesap ara",
    "-oA": "Sonuçları tüm formatlarda (JSON, YAML, TXT) kaydet",
    "-oJ": "Sonuçları JSON dosyasına yaz",
    "-oY": "Sonuçları YAML formatında kaydet",
    "-v": "Ayrıntılı (verbose) çıktı göster",
    "-vv": "Debug seviyesinde ayrıntılı çıktı göster",
    "-debug": "Hata ayıklama modunu etkinleştir",
    "--format": "Parola kırma veya çıktı formatı belirleme",
    "--wordlist": "Saldırıda kullanılacak kelime listesi (wordlist)",
    "--rules": "Parola mutasyon ve kural seti",
    "--fork": "Paralel CPU çekirdek sayısı",
    "-Identity": "Sorgulanacak veya işlem yapılacak hedef nesnenin kimliği (sAMAccountName, DN veya GUID)",
    "-Name": "Oluşturulacak veya hedeflenen nesnenin adı",
    "-w": "Kimlik doğrulama parolası (LDAP) veya kelime listesi dosyası (Wordlist)",
    "-m": "Hashcat hash modu (1000=NTLM, 13100=Kerberoast, 18200=AS-REP) veya modül",
    "-x": "Basit kimlik doğrulama (Simple Bind) kullan veya uzak komut yürütme",
    "-FilterHashtable": "Windows Olay Günlüğü için filtrelenecek anahtar-değer tablosu (LogName, Id vb.)",
    "-i": "Hedef sistem IP adresi veya FQDN",
    "-b": "LDAP arama tabanı (Search Base DN: örn: DC=corp,DC=local)",
    "/c": "CMD veya PowerShell komutunu tek satırda çalıştırıp sonlandır",
    "-D": "LDAP kimlik doğrulama için kullanıcı DN'i (Bind DN: örn: jdoe@corp.local)",
    "-smb2support": "Eski SMBv1 yerine modern SMBv2/v3 protokol desteğini etkinleştir",
    "-r": "RID döngüsü (RID cycling) aralığı veya kural dosyası",
    "-o": "Sonuçların kaydedileceği yerel dosya yolu (Output)",
    "-Path": "Dosya, dizin veya Active Directory nesne yolu",
    "-M": "NetExec / CrackMapExec için çalıştırılacak modül adı",
    "-hashes": "Pass-the-Hash için NTLM özeti (LM:NT veya :NT)",
    "-Properties": "Sorgu çıktısında getirilecek Active Directory öznitelikleri (Attributes)",
    "-c": "Çalıştırılacak komut veya SharpHound veri toplama metodu (DCOnly, All vb.)",
    "-LLL": "LDAP çıktısını açıklamalar ve sürüm bilgisi olmadan temiz LDIF formatında üret",
    "/user": "Hedef etki alanı veya yerel kullanıcı adı",
    "/user:": "Hedef etki alanı veya yerel kullanıcı adı",
    "-Force": "Onay istemeden işlemi zorla yürüt",
    "-TestNumbers": "Invoke-LockoutStatus veya denetim araçlarında test numaraları",
    "/ptt": "Elde edilen Kerberos biletini (TGT/ST) oturum belleğine enjekte et (Pass-the-Ticket)",
    "-s": "LDAP arama kapsamı (scope: base, one, sub) veya sessiz mod",
    "/all": "Tüm kullanıcı, grup veya sistem ayrıntılarını listele",
    "-Filter": "Active Directory veya PowerShell nesnelerini filtreleme ifadesi",
    "-a": "Hashcat saldırı modu (0=Dictionary, 3=Brute-force) veya tüm modülleri çalıştır",
    "-spn": "Hizmet Asıl Adı (Service Principal Name: örn: CIFS/DC01.corp.local)",
    "/add": "Yeni bir nesne, kullanıcı veya yetki ekleme işlemi",
    "-just-dc-user": "DCSync ile yalnızca belirtilen kullanıcının parola hash'ini çek",
    "-ComputerName": "Uzak yönetim veya sorgulama yapılacak bilgisayar/sunucu adı",
    "--template": "AD CS sertifika şablonu adı (örn: ESC1, User, Machine)",
    "--adcs": "AD CS saldırı modülü veya CA sunucu adresi",
    "/domain": "Hedef etki alanı adı (FQDN veya NetBIOS)",
    "/domain:": "Hedef etki alanı adı (FQDN veya NetBIOS)",
    "-impersonate": "Kerberos S4U2Self/S4U2Proxy ile taklit edilecek hedef yönetici hesabı",
    "-SearchBase": "Active Directory sorgusunun başlatılacağı OU veya DN kökü",
    "-Credential": "Farklı bir kimlik bilgisi (PSCredential nesnesi) ile oturum aç",
    "-LogName": "Sorgulanacak Windows Olay Günlüğü adı (Security, System vb.)",
    "-MaxEvents": "Get-WinEvent sorgusunda döndürülecek maksimum olay sayısı",
    "-Oldest": "Olayları en eskiden en yeniye doğru sıralı getir",
    "-asrepkey": "AS-REP Roasting için doğrudan türetilmiş Kerberos anahtarı",
    "-aesKey": "Kerberos kimlik doğrulamasında kullanılacak AES-128 veya AES-256 gizli anahtarı",
    "-nthash": "Kimlik doğrulamasında kullanılacak ham NTLM parola özeti",
    "-altservice": "S4U2Proxy ile bilet taklit ederken hedef alternatif servis adı",
    "-self": "S4U2Self aşamasını tek başına yürütüp bilet al",
    "-request": "KDC'den TGT veya Service Ticket talep et",
    "--pvk": "DPAPI etki alanı yedekleme özel anahtar dosyası (.pvk)",
    "--export-dir": "Elde edilen kimlik bilgilerinin kaydedileceği dizin",
    "--threads": "Eşzamanlı çalıştırılacak iş parçacığı (thread) sayısı",
    "-force-forwardable": "Bronze Bit (CVE-2020-17049) için forwardable bayrağını zorla 1 yap",
    "-action": "Gerçekleştirilecek operasyonel eylem (read, write, dump vb.)",
    "-target": "Hedef sistem IP adresi, FQDN veya nesne adı",
    "-principal": "Yetki atanacak veya manipüle edilecek güvenlik aktörü (kullanıcı/grup)",
    "-rights": "Atanacak veya denetlenecek Active Directory erişim hakları (GenericAll, WriteDacl vb.)",
    "/format:hashcat": "Çıktıyı Hashcat ile kırılabilir formatta üret",
    "/nowrap": "Bilet ve hash verilerini satır bölmesi yapmadan tek satırda bas",
    "/opsec": "SIEM alarmlarını tetiklememek için gürültüyü azaltan koruma modu",
    "/outfile:": "Sonuçların kaydedileceği yerel dosya yolu",
}

def parameterize_command(cmd_text: str) -> str:
    """Komut içindeki sabit değerleri akıllı şablon yer tutucularına çevirir."""
    template = cmd_text
    
    # 1. Hashes
    for h in HASH_PATTERNS:
        template = template.replace(f":{h}", ":{{hash}}")
        template = template.replace(h, "{{hash}}")
        
    # 2. Passwords
    for p in PASS_PATTERNS:
        template = template.replace(f"'{p}'", "'{{pass}}'")
        template = template.replace(f'"{p}"', '"{{pass}}"')
        template = template.replace(f":{p}", ":{{pass}}")
        template = template.replace(p, "{{pass}}")
        
    # 3. DC IP
    for dc_ip in DC_IP_PATTERNS:
        template = template.replace(f"-dc-ip {dc_ip}", "-dc-ip {{dc_ip}}")
        template = template.replace(f"--dc-ip {dc_ip}", "--dc-ip {{dc_ip}}")
        template = template.replace(f"-dc {dc_ip}", "-dc {{dc_ip}}")
        template = template.replace(f"-ns {dc_ip}", "-ns {{dc_ip}}")
        template = template.replace(f"@{dc_ip}", "@{{dc_ip}}")
        template = template.replace(dc_ip, "{{dc_ip}}")
        
    # 4. Target IP
    for tip in TARGET_IP_PATTERNS:
        template = template.replace(f"-target {tip}", "-target {{target_ip}}")
        template = template.replace(f"-i {tip}", "-i {{target_ip}}")
        template = template.replace(f"@{tip}", "@{{target_ip}}")
        template = template.replace(tip, "{{target_ip}}")
        
    # 5. Domain
    for d in DOMAIN_PATTERNS:
        template = re.sub(d, "{{domain}}", template, flags=re.IGNORECASE)
        
    # 6. NetBIOS
    template = re.sub(r'\bCORP\\', '{{netbios}}\\\\', template)
    template = re.sub(r'\bDOMAIN\\', '{{netbios}}\\\\', template)
    template = re.sub(r'\bCONTOSO\\', '{{netbios}}\\\\', template)
    
    # 7. Users
    for u in USER_PATTERNS:
        template = re.sub(rf'\b{u}\b', '{{user}}', template)
        
    return template

def detect_platform(code: str, tool_name: str) -> str:
    """Komutun platformunu tespit eder."""
    lowered = code.lower()
    tool_low = tool_name.lower()
    
    if any(k in lowered for k in ['get-domain', 'invoke-', 'set-domain', 'add-domain', '$null', 'powershell', '[ref].assembly', 'get-ad', 'set-ad', 'new-ad', 'enable-ad', 'import-module']):
        return "PowerShell"
    if any(k in lowered for k in ['rubeus.exe', 'mimikatz.exe', 'certify.exe', 'seatbelt.exe', 'sharphound.exe', 'sharp', 'cmd.exe', 'c:\\', 'nltest', 'dsquery', 'repadmin', 'dcdiag', 'ntdsutil', 'certutil']):
        return "Windows CMD / Binary"
    if any(k in lowered for k in ['sudo ', 'impacket-', 'python3 ', 'export ', 'proxychains', 'curl ', 'git ']) or tool_low.startswith('impacket') or tool_low.startswith('python'):
        return "Linux CLI"
    if 'match ' in lowered or 'return ' in lowered or 'where ' in lowered:
        return "Cypher / Query"
    return "Linux / Cross-Platform"

def extract_event_ids(text: str) -> list:
    """Metin içerisindeki Event ID numaralarını tespit eder."""
    matches = re.findall(r'(?:Event\s*ID\s*|ID\s*)(\d{4})', text, re.IGNORECASE)
    valid_ids = sorted(list(set(m for m in matches if 1000 <= int(m) <= 9000)))
    return valid_ids[:5]

def extract_section2_flags(content: str) -> dict:
    """Section 2 içerisindeki CLI bayrak tablolarını ayrıştırır (İlk tanımı korur)."""
    sec2 = re.search(r'## 2\. Temel Sözdizimi.*?(?=## 3|\Z)', content, re.DOTALL)
    if not sec2:
        return {}
    flags = {}
    for line in sec2.group(0).split('\n'):
        if '|' in line and not line.strip().startswith('|---'):
            cols = [c.strip().strip('`') for c in line.split('|')[1:-1]]
            if len(cols) < 2:
                continue
            flag_col_idx = -1
            for idx, col in enumerate(cols):
                if re.search(r'(-{1,2}[a-zA-Z0-9_\-]+|/[a-zA-Z0-9_\-]+)', col) and not '---' in col and not 'Parametre' in col and not 'Bayrak' in col:
                    flag_col_idx = idx
                    break
            if flag_col_idx != -1:
                desc_col_idx = -1
                for idx, col in enumerate(cols):
                    if idx != flag_col_idx and len(col) > 4 and not col.startswith('-') and not col.startswith('/'):
                        desc_col_idx = idx
                        break
                desc = cols[desc_col_idx] if desc_col_idx != -1 else (cols[-1] if len(cols) > 1 else '')
                found_flags = re.findall(r'(-{1,2}[a-zA-Z0-9_\-]+|/[a-zA-Z0-9_\-]+)', cols[flag_col_idx])
                for fl in found_flags:
                    if fl not in flags:
                        flags[fl] = desc
    return flags

def parse_bullet_parameters(params_text: str) -> dict:
    """Parametreler metnindeki madde işaretli veya virgüllü tanımları ayrıştırır."""
    parsed = {}
    if not params_text:
        return parsed
    
    cleaned = params_text.replace('`', '')
    
    bullet_items = re.findall(r'(?:^|\n)\s*[\*\-]\s*([^\s:\n]+)\s*:\s*([^\n]+)', cleaned)
    for k, v in bullet_items:
        clean_k = k.strip('*- :')
        clean_v = v.strip('*- ')
        if clean_k and clean_v:
            parsed[clean_k] = clean_v
            
    if not parsed:
        inline_items = re.findall(r'(-{1,2}[a-zA-Z0-9_\-]+|/[a-zA-Z0-9_\-]+(?::[^\s\),]+)?)\s*[\(:]([^,\)\n]+)[\)]?', cleaned)
        for fl, desc in inline_items:
            fl_clean = fl.strip()
            desc_clean = desc.strip(' )')
            if fl_clean and desc_clean:
                parsed[fl_clean] = desc_clean
                
    return parsed

def analyze_p_in_command(raw_code: str, tool_name: str = "") -> list:
    """
    Komuttaki -p bayrağını akıllı bağlamsal analize tabi tutar:
    1. Standalone / Değersiz -> Yazıcı sorgulama (RpcEnumPrinters)
    2. Sayı / Port -> Hedef port numarası
    3. Dosya / Payload yolu -> Dosya yolu
    4. Parola (string/quote/placeholder) -> Kullanıcı parolası
    """
    if 'mkdir -p' in raw_code or tool_name.lower() == 'mkdir':
        return [("-p", "Hedef üst dizinleri oluştur (parents)")]
        
    matches = list(re.finditer(r'(?:^|\s)-p(?:\s+([^\s]+)|\s*$)', raw_code))
    if not matches:
        return []
    
    res = []
    has_multiple = len(matches) > 1
    
    for idx, m in enumerate(matches):
        val = m.group(1) if m.group(1) else ''
        val_clean = val.strip('\"\'')
        
        # 1. Standalone
        if not val or val.startswith('-') or val.startswith('/'):
            flag_name = "-p (Yazıcı)" if has_multiple else "-p"
            desc = "Ağda paylaşılan yazıcıları sorgular/listeler (RpcEnumPrinters)" if "enum4linux" in tool_name.lower() else "Yazıcıları listele"
            res.append((flag_name, desc))
        # 2. Port number
        elif re.match(r'^\d+(?:,\d+)*(?:-\d+)?$', val_clean):
            flag_name = "-p (Port)" if has_multiple else "-p"
            desc = f"Hedef servis port numarası ({val_clean})"
            res.append((flag_name, desc))
        # 3. Target IP at end of enum4linux (enum4linux -p 192.168.1.10)
        elif "enum4linux" in tool_name.lower() and re.match(r'^(?:\d{1,3}\.){3}\d{1,3}$', val_clean) and not any(f in raw_code for f in ['-u', '--user']):
            flag_name = "-p (Yazıcı)" if has_multiple else "-p"
            desc = "Ağda paylaşılan yazıcıları sorgular/listeler (RpcEnumPrinters)"
            res.append((flag_name, desc))
        # 4. File / payload path
        elif re.search(r'(\.exe|\.dll|\.bin|\.ps1|\.sh|\.txt|\.pvk)$', val_clean, re.I) or val_clean.startswith(('C:', 'c:', './', '../')):
            flag_name = "-p (Dosya)" if has_multiple else "-p"
            desc = f"Yürütülecek dosya / payload dosya yolu ({val_clean})"
            res.append((flag_name, desc))
        # 5. Password
        else:
            flag_name = "-p (Parola)" if has_multiple else "-p"
            desc = "Kullanıcı açık metin parolası (Kimlik doğrulama)"
            res.append((flag_name, desc))
            
    return res

def build_parameter_breakdown(raw_code: str, raw_params_text: str, tool_flags: dict, tool_name: str = "", platform: str = "") -> tuple:
    """Komuttaki her bayrağı tespit eder ve açıklama listesi oluşturur."""
    local_parsed = parse_bullet_parameters(raw_params_text)
    
    is_powershell = platform == "PowerShell" or any(
        w in raw_code.lower() for w in ['powershell', 'cmdlet', 'select-object', 'where-object', 'get-', 'set-', 'invoke-', '[pscustomobject]']
    ) or '$' in raw_code
    
    is_windows = is_powershell or platform.startswith("Windows") or any(
        w in raw_code.lower() for w in ['.exe', 'cmd.exe', 'nltest', 'cmdkey', 'whoami', 'klist', 'dsquery']
    )
    
    if is_windows:
        raw_flags = re.findall(r'(?:^|\s)(-[a-zA-Z0-9_\-]+|--[a-zA-Z0-9_\-]+|/(?!opt/|tmp/|etc/|usr/|var/|home/|root/|bin/|dev/|media/|mnt/)[a-zA-Z0-9_\-]+(?::[^\s]+)?)', raw_code)
    else:
        raw_flags = re.findall(r'(?:^|\s)(-[a-zA-Z0-9_\-]+|--[a-zA-Z0-9_\-]+)', raw_code)

    param_list = []
    seen_flags = set()
    
    p_analysis = analyze_p_in_command(raw_code, tool_name)
    
    for fl in raw_flags:
        if fl.startswith('/') and ('/' in fl[1:] or fl.lower() in ['/opt', '/tmp', '/etc', '/var', '/usr', '/root', '/home']):
            continue
            
        base_fl = fl.split(':')[0]
        
        # PowerShell karşılaştırma operatörlerini (-eq, -like, -match, -and, -notmatch vb.) bayrak sanma!
        if (is_windows or is_powershell) and base_fl.lower() in POWERSHELL_OPERATORS:
            continue
            
        if base_fl.lower() in seen_flags:
            continue
        seen_flags.add(base_fl.lower())
        
        desc = ""
        if base_fl == '-p':
            if len(p_analysis) == 1:
                desc = p_analysis[0][1]
            elif len(p_analysis) > 1:
                for p_fl, p_desc in p_analysis:
                    if p_fl.lower() not in seen_flags:
                        param_list.append({"flag": p_fl, "desc": p_desc})
                        seen_flags.add(p_fl.lower())
                continue
        elif fl in local_parsed:
            desc = local_parsed[fl]
        elif base_fl in local_parsed:
            desc = local_parsed[base_fl]
        elif fl in tool_flags:
            desc = tool_flags[fl]
        elif base_fl in tool_flags:
            desc = tool_flags[base_fl]
        elif fl in COMMON_AD_FLAGS:
            desc = COMMON_AD_FLAGS[fl]
        elif base_fl in COMMON_AD_FLAGS:
            desc = COMMON_AD_FLAGS[base_fl]
            
        if base_fl == '-u' and not desc:
            desc = "Kimlik doğrulamada kullanılacak kullanıcı adı"
            
        if not desc:
            desc = f"{base_fl} operasyonel parametresi"
            
        clean_display_flag = base_fl if ':' in fl else fl
        param_list.append({"flag": clean_display_flag, "desc": desc})
        seen_flags.add(clean_display_flag.lower())
        
    for k, v in local_parsed.items():
        clean_k = k.strip('`* ')
        if not clean_k or clean_k.lower() in ['genel parametreler', 'parametreler']:
            continue
        base_k = clean_k.split()[0].split(':')[0]
        if (is_windows or is_powershell) and base_k.lower() in POWERSHELL_OPERATORS:
            continue
        if base_k.lower() in seen_flags or any(p['flag'].lower() == clean_k.lower() or p['flag'].lower() == base_k.lower() for p in param_list):
            continue
        if not base_k.startswith('/') or is_windows:
            param_list.append({"flag": clean_k, "desc": v})
            seen_flags.add(base_k.lower())
            
    if not param_list and raw_params_text:
        clean_gen = raw_params_text.strip('`* ')
        if clean_gen and clean_gen.lower() not in ['genel parametreler', 'parametreler']:
            param_list.append({"flag": "Genel Parametreler", "desc": clean_gen})
        
    lines = []
    for p in param_list:
        lines.append(f"• {p['flag']}: {p['desc']}")
    formatted_text = "\n".join(lines) if lines else raw_params_text
    
    return param_list, formatted_text

def strip_prompt(cmd: str) -> str:
    r"""Terminal / shell komut istemi kalıntılarını (C:\>, root@kali:~# vb.) temizler."""
    cleaned = re.sub(r'^(?:[A-Za-z]:\\[^>]*>|PS\s+[A-Za-z]:\\[^>]*>|root@[^:#]+:[^#]+#\s*|\$\s+|rpcclient\s*\$>\s*|beacon>\s*)', '', cmd).strip()
    return cleaned

def is_executable_command_clean(code: str, lang: str = "", title: str = "") -> bool:
    """Kod bloğunun gerçek, çalıştırılabilir bir operasyonel komut veya sorgu olup olmadığını doğrular."""
    raw = code.strip()
    if not raw or len(raw) < 4:
        return False
        
    lines = [l.strip() for l in raw.split('\n') if l.strip()]
    non_comment_lines = [l for l in lines if not l.startswith(('#', '//', '::', '<!--'))]
    if not non_comment_lines:
        return False
        
    first_non_comment = non_comment_lines[0]
    
    # 1. Sigma / YARA / KQL / XML tespit ve kural şablonları
    if any(line.startswith(('title:', 'description:', 'author:', 'logsource:', 'detection:', 'condition:', 'rule Indicator_', 'rule ', '<Subscription', '<?xml')) for line in lines):
        return False
    if any(s in raw for s in ['<Sysmon', '<EventFiltering', '<RuleGroup', '<QueryList', '<form ', '<input ']):
        return False
        
    # 2. Markdown tabloları, ASCII akış şemaları ve diyagramlar
    if any(line.startswith('|') and '|' in line[1:] for line in lines):
        return False
    if any(symbol in raw for symbol in [
        '┌──', '├──', '└──', '│', '───', '===', '└─', '+---', '|---', '──▶', '──►', '-->', '◄──',
        '▲', '▼', '◀', '▶', '┌', '┐', '└', '┘', '├', '┤', '┬', '┴', '┼', '═'
    ]):
        return False
    if any(s in raw for s in ['OPSEC GÜRÜLTÜ', '0 ------', '0 ----[', '------[']):
        return False
        
    # 3. GUI / Arayüz yönergeleri (adım adım tıklama yolları)
    if any(term in raw for term in [
        'Computer Configuration →', 'Computer Configuration ->', 'User Configuration →', 'User Configuration ->',
        'GPO:', 'Event Viewer →', 'Active Directory Users and Computers →', 'ldp.exe →', 'adsiedit.msc →',
        'Group Policy Management →', 'dsa.msc →', 'certsrv.msc →', 'compmgmt.msc →'
    ]):
        return False
        
    # 4. İnteraktif terminal / konsol çıktısı veya log dökümü
    output_prefixes = [
        'Loaded ', 'Administrator:', 'Domain Name:', 'Metot ', 'UAC ', 'dn:', 'defaultNamingContext:',
        'Computer Config', 'User Config', 'Adım ', 'NOT:', 'Rule ', 'Flags: 0x',
        '[+] ', '[*] ', '[-] ', '[!] ', '[DC] ', '[SMB] ', '[HTTP] ', '[LDAP] ', '[Agent',
        '[ntlmrelayx', '[Rubeus', '[Responder', '[OPSEC', 'NTLMv2-SSP Client'
    ]
    if any(first_non_comment.startswith(p) for p in output_prefixes):
        return False
    if any(l.startswith(('ntdsutil:', 'beacon>', 'rpcclient $>', 'mimikatz #', 'kerberos::', 'C:\\>')) for l in lines[:3]):
        if any('Active instance set to' in l or 'mimikatz(powershell)' in l or 'Privilege ' in l for l in lines):
            return False
            
    # 5. User-Agent, Event ID ve salt ağ/EDR imza alanları
    if any(line.startswith(('User-Agent:', 'Event ID:', 'EventID:', 'Olay Kimliği:', 'Provider_Name:')) for line in lines):
        return False
    if ('Ağ ve EDR İmzaları' in title or 'Bırakılan İzler' in title) and not any(k in raw.lower() for k in ['powershell', 'get-winevent', 'wevtutil', 'mimikatz', 'rubeus', 'certipy', 'nxc']):
        return False

    # 6. Kayıt Defteri (Registry) anahtar yolu tek başına
    if (first_non_comment.startswith(('HKLM\\', 'HKCU\\', 'HKEY_LOCAL_MACHINE\\', 'HKEY_CURRENT_USER\\')) and 
        not any(first_non_comment.lower().startswith(p) for p in ['reg ', 'reg.exe', 'powershell', 'get-item', 'set-item'])):
        return False

    # 7. Salt URL veya dosya yolu
    if (first_non_comment.startswith(('http://', 'https://', 'C:\\Windows\\System32\\')) and ' ' not in first_non_comment):
        return False

    # 8. LDAP bitmask veya RFC 4515 sözdizim şablonları
    if first_non_comment.startswith('(') and any(k in first_non_comment for k in ['<öznitelik>', 'eşleme_kuralı', ':=', '→']):
        if not any(cmd_w in raw.lower() for cmd_w in ['ldapsearch', 'dsquery', 'get-ad', 'adfind']):
            return False

    # 9. Düz metin / metodoloji / soru / kontrol listesi cümleleri
    prose_starters = [
        r'^(?:Normal akış|USN Rollback|Link doğru mu\?|Bu |Aşağıdaki|Şayet|Eğer|Not:|Dikkat:|Örnek:|Kullanıcı |Saldırgan |Hedef |Yöntem |Metot |Aşama |Senaryo |Gerekli |Öncelikle |Ardından |Sonrasında |Sonuç: |Çıktı: |Analiz: |Tespit: |Çözüm: |Neden: |Durum: |Özet: |Tanım: |Açıklama: |Faydalı |Tavsiye |Bilgi |Öneri:)\b',
        r'^(?:Şablon:|Yön:|Adım\s*\d+:|Faz\s*\d+:|Phase\s*\d+:|Step\s*\d+:)\b',
        r'^(?:Soru:|Cevap:|Teori:|Mimarisi:|Çalışma Prensibi:)\b',
        r'^(?:1\)\s+|2\)\s+|3\)\s+|1\.\s+[A-ZÇĞİÖŞÜ]|2\.\s+[A-ZÇĞİÖŞÜ])',
        r'^(?:T10|T11|T12|T15)\d{2}',
    ]
    for pat in prose_starters:
        if re.search(pat, first_non_comment, re.IGNORECASE):
            if not any(k in raw.lower() for k in ['powershell', 'cmd.exe', 'nxc ', 'mimikatz', 'rubeus', 'certipy', 'impacket-', 'curl ', 'wget ', 'nmap ']):
                return False

    # 10. Python scriptleri ve DSC konfigürasyon blokları
    if raw.startswith(('from ldap3 import', 'import ssl', 'import os', 'import sys', '[DSCLocalConfigurationManager()]', 'Configuration ')):
        return False
        
    # 11. Cypher sorgusu (BloodHound için geçerli komut)
    if any(first_non_comment.startswith(k) for k in ['MATCH ', 'MATCH(', 'CREATE ', 'RETURN ']):
        return True
        
    # 12. PowerShell Cmdlet / Script
    if re.search(r'^(?:(?:Get|Set|New|Remove|Enable|Disable|Add|Clear|Test|Search|Invoke|Select|Where|Start|Stop|Restart|Export|Import|Resolve|Measure|Compare|Install|Uninstall)-[A-Za-z0-9]+|\$[a-zA-Z0-9_]+\s*=|\[[A-Za-z0-9_\.]+\])', first_non_comment):
        return True
        
    # 13. Bilinen CLI Araçları
    cli_tokens = [
        'impacket-', 'nxc', 'crackmapexec', 'cme', 'rubeus', 'mimikatz', 'certipy', 'certify', 'bloodhound',
        'sharphound', 'responder', 'mitm6', 'ntlmrelayx', 'hashcat', 'john', 'hydra', 'kerbrute', 'ldapsearch',
        'rpcclient', 'evil-winrm', 'chisel', 'ligolo', 'powershell', 'cmd', 'curl', 'wget', 'nmap', 'sqlmap',
        'nltest', 'dsquery', 'dsget', 'repadmin', 'dcdiag', 'ntdsutil', 'certutil', 'klist', 'kinit', 'whoami',
        'net', 'net1', 'sc', 'reg', 'schtasks', 'wmic', 'tasklist', 'ipconfig', 'wevtutil', 'auditpol', 'secedit',
        'vssadmin', 'wbadmin', 'sudo', 'export', 'chmod', 'mkdir', 'findstr', 'grep', 'python3', 'python',
        'Get-WinEvent', 'SecurityEvent', 'DeviceProcessEvents', 'WinEvent', 'adfind', 'admod', 'seatbelt',
        'safetykatz', 'sharpup', 'sharpview', 'sharpdpapi', 'sharpwmi', 'sharpchrome', 'snaffler', 'coercer',
        'petitpotam', 'dfscoerce', 'shadowcoerce', 'printerbug', 'spoolsample', 'demodal', 'bloodyad',
        'pywerview', 'ldapdomaindump', 'adalanche', 'pingcastle', 'gowitness', 'gowinrm', 'pre2k', 'masky',
        'netsh', 'route', 'arp', 'systeminfo', 'gpupdate', 'gpresult', 'ping', 'tracert', 'nslookup',
        'execute-assembly', 'inline-execute', 'bof-netexec', 'lsassy', 'donpapi', 'pypykatz', 'gpp-decrypt'
    ]
    first_word = first_non_comment.split()[0].lower().strip('`"\'(').split('/')[-1].replace('.exe', '').replace('.py', '').replace('.ps1', '')
    if any(first_word == ct or first_non_comment.lower().startswith(ct) for ct in cli_tokens):
        return True
        
    # 14. CLI bayrakları barındıran komutlar
    has_flags = bool(re.search(r'(?:^|\s)(?:-[a-zA-Z0-9_\-]+|--[a-zA-Z0-9_\-]+|/[a-zA-Z0-9_\-]+:?)\s+', raw))
    if has_flags and len(raw.split()) <= 40 and not any(turkish_word in raw.lower() for turkish_word in ['nedir', 'çünkü', 'olmalıdır', 'şeklinde', 'yapılır', 'gerekmektedir']):
        return True

    # 15. Faz / Adım / Senaryo bloklarını ve Python tuple/list çıktılarını filtrele
    if re.match(r'^\s*\[(?:Faz|Adım|Senaryo|Aşama|Step|Phase|Blue)\s*[\d\.]+', first_non_comment, re.IGNORECASE):
        return False
    if first_non_comment.startswith(("[('", '[{"', "[{ '")):
        return False
        
    # 16. Doğal dil / Türkçe cümle kontrolü
    if len(raw.split()) > 15 and not any(k in raw for k in ['|', '$', '-', '/']):
        return False
    turkish_sentence_words = ['veya', 'için', 'ile', 'üzerinden', 'tarafından', 'sonra', 'önce', 'göre', 'kadar', 'olarak', 'olan', 'edilen']
    found_tw = sum(1 for w in turkish_sentence_words if f" {w} " in f" {raw.lower()} ")
    if found_tw >= 2 and not has_flags:
        return False

    if not has_flags and not any(symbol in raw for symbol in ['$', '|', '>', '<', '\\', '/']):
        return False
        
    return True

def clean_tool_name(first_w: str, raw_code: str, article_title: str) -> str:
    """Komuttan çıkarılan araç adını temizler ve geçerli bir başlığa dönüştürür."""
    cleaned = first_w.strip('`"\'')
    # PowerShell cmdlet parantezli çağrı: (Get-ADUser -Filter ...).Property -> Get-ADUser
    m = re.match(r'^\(?([A-Za-z0-9_\-]+(?:\.[A-Za-z0-9_\-]+)?)\)?', cleaned)
    if m:
        cleaned = m.group(1)
        
    # Eğer [..] ile veya geçersiz karakterle başlıyorsa makale başlığına dön
    if cleaned.startswith(('[', '(', '<', '{', '/', '\\', '|', '#', '!', ':', ';', '=')) or len(cleaned) < 2:
        return article_title
        
    if cleaned.startswith('$'):
        return article_title
        
    # Python / wrapper betikleri: python3 secretsdump.py -> secretsdump
    parts = raw_code.split()
    if cleaned.lower() in ['python', 'python3', 'sudo', 'proxychains', 'powershell', 'cmd'] and len(parts) > 1:
        next_w = parts[1].split('/')[-1].replace('.exe', '').replace('.py', '').replace('.ps1', '').strip('`"\'')
        if len(next_w) > 2 and not next_w.startswith('-'):
            return next_w
            
    # Sonundaki noktalama işaretlerini temizle
    cleaned = re.sub(r'[\.:,\(\)\[\]]+$', '', cleaned)
    
    return cleaned if len(cleaned) >= 2 else article_title

def extract_document_commands(filepath: Path) -> list:
    """Tek bir Markdown dokümanındaki TÜM bölümleri tarar ve tüm çalıştırılabilir komutları çıkarır."""
    if filepath.name.lower() == "playbook.md":
        return []
    content = filepath.read_text(encoding="utf-8")
    lines = content.split('\n')
    
    title_line = lines[0].replace('#', '').strip() if lines else filepath.stem
    article_title = re.sub(r'^[0-9\.]+\s*—\s*', '', title_line).strip()
    
    doc_id = hashlib.md5(f"{filepath.parent.name}/{filepath.name}".encode()).hexdigest()[:10]
    doc_path = str(filepath.relative_to(BASE_DIR))
    
    # Kategori belirleme
    parent_dir = filepath.parent.name
    if "Kategori_" in parent_dir:
        category = re.sub(r'^Kategori_\d+_', '', parent_dir).replace('_', ' ')
    elif filepath.parent.parent.name == "3-Red_Team":
        cat_match = re.match(r'Modul_(\d+)_(.*)', parent_dir)
        category = f"Red Team: M{cat_match.group(1)} - {cat_match.group(2).replace('_', ' ')}" if cat_match else "Red Team Taktik"
    elif filepath.parent.parent.name == "2-Blue_Team":
        cat_match = re.match(r'Modul_(\d+)_(.*)', parent_dir)
        category = f"Blue Team: M{cat_match.group(1)} - {cat_match.group(2).replace('_', ' ')}" if cat_match else "Blue Team"
    elif filepath.parent.parent.name == "1-Sistem_Yoneticisi":
        cat_match = re.match(r'Modul_(\d+)_(.*)', parent_dir)
        category = f"Sistem Yöneticisi: M{cat_match.group(1)} - {cat_match.group(2).replace('_', ' ')}" if cat_match else "Sistem Yöneticisi"
    else:
        category = "Active Directory"

    tool_flags = extract_section2_flags(content)
    event_ids = extract_event_ids(content)
    
    sec5 = re.search(r'## 5\..*?(?=## [67]|\Z)', content, re.DOTALL)
    opsec_note = ""
    if sec5:
        ol = [l.strip() for l in sec5.group(0).split('\n') if l.strip().startswith(('*', '-', '1.', '2.', '|'))]
        if ol:
            opsec_note = ol[0].lstrip('*- 12.|')[:160] + "..."

    # Dokümanı ana başlıklara göre (## ) böl
    sections = re.split(r'\n(?=##\s+)', content)
    extracted = []
    seen_raw_commands = set()
    cmd_idx = 1
    slug = re.sub(r'[^a-zA-Z0-9]+', '_', article_title.lower()).strip('_')
    
    for sec in sections:
        sec = sec.strip()
        if not sec:
            continue
        sec_first = sec.split('\n')[0].strip()
        sec_header = re.sub(r'^##\s+', '', sec_first).strip()
        
        # Teorik ve statik bölümleri atla
        if any(term in sec_header.lower() for term in ['kaynaklar', 'içindekiler', 'mitre att&ck', 'bırakılan izler', 'ağ ve edr imzaları']):
            continue
            
        # Alt bloklara böl (###, #### veya kod blokları)
        split_pattern = r'\n(?=###?\s*(?:Senaryo\s*\d+:?|Komut\s*\d+:?|\d+(?:\.\d+)?\.\s*|[^\n]+)|####?\s*\d+\.\s*|```[a-zA-Z0-9_\-]*\n\s*(?://|#|::)\s*\d+\.)'
        sub_blocks = re.split(split_pattern, sec)
        
        for block in sub_blocks:
            block = block.strip()
            if not block:
                continue
                
            code_matches = list(re.finditer(r'```([a-zA-Z0-9_\-]+)?\n(.*?)```', block, re.DOTALL))
            for cm in code_matches:
                lang = cm.group(1) or ""
                raw_code = cm.group(2).strip()
                raw_code = strip_prompt(raw_code)
                
                if not is_executable_command_clean(raw_code, lang):
                    continue
                    
                norm_cmd = " ".join(raw_code.split())
                if norm_cmd in seen_raw_commands:
                    continue
                seen_raw_commands.add(norm_cmd)
                
                # Başlık belirleme
                first_line = block.split('\n')[0].strip()
                t_match = re.search(r'(?:###+|####?)\s*(?:Senaryo\s*\d+:?|Komut\s*\d+:?|\d+(?:\.\d+)?\.\s*)?([^\n]+)', first_line)
                if t_match and not first_line.startswith('## 1.') and not first_line.startswith('## 2.'):
                    title = t_match.group(1).strip(' *`#')
                else:
                    comment_m = re.search(r'(?://|#|::)\s*(?:\d+\.\s*)?([^\n]+)', raw_code)
                    if comment_m:
                        title = comment_m.group(1).strip()
                    else:
                        title = f"{article_title} — {sec_header.split('(')[0].strip()}"
                        
                title = re.sub(r'^[#\s\-*]+', '', title).replace('**', '').strip()
                if len(title) > 90:
                    title = title[:87] + "..."
                    
                # Ne Yapar?
                what_match = re.search(r'\*\*Ne Yapar\?\*?\*?:?\s*(.*?)(?=\n-|\n\*|\n###|\Z)', block, re.DOTALL)
                if what_match:
                    what_it_does = what_match.group(1).strip()
                else:
                    pre_text = block[:cm.start()].strip().split('\n')
                    desc_lines = [p.strip() for p in reversed(pre_text) if p.strip() and not p.strip().startswith(('#', '|', '>', '```', '---')) and len(p.strip()) > 10]
                    what_it_does = desc_lines[0] if desc_lines else f"{article_title} ile operasyonel komutu yürütür."
                what_it_does = re.sub(r'\s+', ' ', what_it_does).strip()
                
                # Ne Zaman Kullanılır?
                when_match = re.search(r'\*\*Ne Zaman Kullanılır\?\*?\*?:?\s*(.*?)(?=\n-|\n\*|\n###|\Z)', block, re.DOTALL)
                if when_match:
                    when_to_use = when_match.group(1).strip()
                else:
                    when_to_use = f"{article_title} kapsamında ilgili sızma testi, analiz veya yönetim aşamasında kullanılır."
                when_to_use = re.sub(r'\s+', ' ', when_to_use).strip()
                
                # Parametreler
                params_match = re.search(r'\*\*Parametreler:\*?\*?:?\s*(.*?)(?=\n-|\n\*|\n###|\Z)', block, re.DOTALL)
                raw_params = params_match.group(1).strip() if params_match else ""
                
                # Araç adı belirleme
                exec_first = [l.strip() for l in raw_code.split('\n') if l.strip() and not l.strip().startswith(('#', '//', '::'))][0]
                first_w = exec_first.split()[0].split('/')[-1].replace('.exe', '').replace('.py', '').replace('.ps1', '')
                tool_name = clean_tool_name(first_w, raw_code, article_title)
                
                platform = detect_platform(raw_code, tool_name)
                param_list, formatted_params = build_parameter_breakdown(raw_code, raw_params, tool_flags, tool_name=tool_name, platform=platform)
                template = parameterize_command(raw_code)
                cmd_id = f"cmd_{slug}_{cmd_idx}"
                
                extracted.append({
                    "id": cmd_id,
                    "tool": tool_name,
                    "category": category,
                    "platform": platform,
                    "title": title,
                    "rawCommand": raw_code,
                    "template": template,
                    "whatItDoes": what_it_does,
                    "whenToUse": when_to_use,
                    "parameters": formatted_params,
                    "parameterList": param_list,
                    "opsec": opsec_note or "Sistem telemetrisi ve olay günlükleri tarafından izlenir.",
                    "eventIds": event_ids,
                    "docPath": doc_path,
                    "docId": doc_id
                })
                cmd_idx += 1
                
    return extracted

def main():
    print("=================================================================")
    print("  ⚡ ACTIVE DIRECTORY VAULT — TÜM DOKÜMANLARI KAPSAYAN TAM CEPHANELİK")
    print("=================================================================")
    
    all_files = sorted(
        glob.glob(str(BASE_DIR / "3-Red_Team" / "**" / "*.md"), recursive=True) +
        glob.glob(str(BASE_DIR / "2-Blue_Team" / "**" / "*.md"), recursive=True) +
        glob.glob(str(BASE_DIR / "1-Sistem_Yoneticisi" / "**" / "*.md"), recursive=True)
    )
    all_files = [Path(f) for f in all_files if not f.endswith("README.md")]
    
    print(f"[*] Taranan Toplam Doküman Sayısı: {len(all_files)}")
    
    catalog = []
    for f in all_files:
        cmds = extract_document_commands(f)
        catalog.extend(cmds)
        
    print(f"[✓] TOPLAM ÇIKARILAN OPERASYONEL KOMUT: {len(catalog)}")
    
    has_param_list = sum(1 for c in catalog if c.get("parameterList") and len(c.get("parameterList")) > 0)
    print(f"📊 Parametre Analizi Olan Komutlar: {has_param_list} / {len(catalog)} (%{has_param_list*100/len(catalog):.1f})")
    
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_FILE, "w", encoding="utf-8") as out:
        json.dump(catalog, out, ensure_ascii=False, indent=2)
        
    size_kb = os.path.getsize(OUTPUT_FILE) / 1024
    print(f"[✓] Komut Kataloğu Kaydedildi: {OUTPUT_FILE} ({size_kb:.1f} KB)")
    print("=================================================================")

if __name__ == "__main__":
    main()
