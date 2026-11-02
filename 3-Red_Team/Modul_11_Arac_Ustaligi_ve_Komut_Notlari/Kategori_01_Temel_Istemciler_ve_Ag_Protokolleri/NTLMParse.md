# NTLMParse

> **Kategori:** [1. Temel İstemciler ve Ağ Protokol Araçları](./README.md) · **Modül:** [Modül 11 — Araç Cephaneliği](../README.md)
> **Tanım:** Base64 veya ham hex formatında kodlanmış NTLM mesajlarını (Type 1 Negotiate, Type 2 Challenge, Type 3 Authenticate) bayt düzeyinde ayrıştıran; hedef bilgisayar adı, NetBIOS/DNS etki alanı adı, işletim sistemi tam yapı numarası (OS Build) ve bayrakları (Negotiate Flags) anında deşifre eden protokoler analiz aracı.

---

## 1. Genel Bakış ve Amaç

Web uygulamalarında (IIS, OWA, EWS), ağ paket yakalamalarında (PCAP) veya HTTP proxy (Burp Suite) kayıtlarında NTLM kimlik doğrulama başlığı `Authorization: NTLM TlRMTVNTUAABAAA...` şeklinde Base64 dizgisi olarak geçer. Bu dizgiler şifreli görünse de, NTLMSSP protokolü gereği ilk iki mesaj (Type 1 ve Type 2) şifresiz sistem meta verileri barındırır.

**`NTLMParse`**, bu Base64 dizgilerini girdi olarak alıp NTLMSSP spesifikasyonuna göre ayrıştırır:
- **Type 1 (Negotiate):** İstemcinin desteklediği bayrakları (Unicode, OEM, NTLMv2, 128-bit şifreleme) ve istemci iş istasyonu adını gösterir.
- **Type 2 (Challenge):** Sunucunun kimliğini (NetBIOS Bilgisayar Adı, NetBIOS Etki Alanı, DNS Ağaç Adı, FQDN), sunucu zaman damgasını (Timestamp) ve en önemlisi hedef sunucunun tam işletim sistemi sürümünü (Örn: Windows Server 2022 Build 20348) sızdırır.
- **Type 3 (Authenticate):** Oturum açmaya çalışan kullanıcının etki alanı, kullanıcı adı ve istemci bilgisayar adını gösterir.

### Mimari Akış Şeması

```
[ HTTP İstek / Yanıt Başlığı ]
Authorization: NTLM TlRMTVNTUAACAAAADAAMADAAAA...
                │
                ├── (Base64 Decode)
                ▼
┌─────────────────────────────────────────────────────────────┐
│ NTLMSSP Header (Bytes 0-7: 'NTLMSSP\0')                    │
├─────────────────────────────────────────────────────────────┤
│ MessageType (Bytes 8-11: 0x00000002 -> Type 2 Challenge)   │
├─────────────────────────────────────────────────────────────┤
│ TargetName (Length / Offset -> 'CORP-DC01')                 │
├─────────────────────────────────────────────────────────────┤
│ NegotiateFlags (0x00028205 -> Unicode, Request Target, NTLM)│
├─────────────────────────────────────────────────────────────┤
│ ServerChallenge (8 Bytes: e1 f4 9b 12 7c 34 a0 ff)         │
├─────────────────────────────────────────────────────────────┤
│ TargetInfo (AV_PAIRS):                                      │
│   MsvAvNbDomainName: CORP                                   │
│   MsvAvNbComputerName: DC01                                 │
│   MsvAvDnsDomainName: corp.local                            │
│   MsvAvDnsComputerName: dc01.corp.local                     │
│   MsvAvTimestamp: 2026-11-02 12:40:00 UTC                   │
├─────────────────────────────────────────────────────────────┤
│ OS Version (Major: 10, Minor: 0, Build: 20348 -> Server 2022)│
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Temel Sözdizimi ve Parametreler (CLI Flags)

```bash
NTLMParse [BASE64_DIZGISI]
# veya boru (pipe) ile girdi:
echo "<BASE64_NTLM>" | NTLMParse
```

### Parametreler

| Parametre | Açıklama | Örnek Değer |
|---|---|---|
| `<BASE64_STRING>` | Ayrıştırılacak Base64 formatlı NTLM token'ı | `TlRMTVNTUAAC...` |
| `-f <DOSYA>` | İçinde NTLM başlıkları bulunan dosya yolu | `-f auth_headers.txt` |
| `-json` | Çıktıyı makine tarafından okunabilir JSON formatında verir | `-json` |

---

## 3. Pratik Komut Örnekleri

### Senaryo 1: IIS / Exchange Sunucu Sürümünü Tespit Etme (Type 2 Challenge)

Bir web sunucusuna HTTP isteği gönderilerek NTLM Challenge alınır ve NTLMParse ile sunucunun iç IP/adı ve tam OS versiyonu deşifre edilir:

```bash
# 1. Curl ile Type 1 Negotiate gönderip Type 2 yanıtını yakalama
export CHALLENGE=$(curl -s -I -k --ntlm -u ":" https://mail.corp.local/owa | grep -i "www-authenticate: NTLM" | awk '{print $3}')

# 2. Yakalanan Base64 NTLM verisini NTLMParse ile çözme
echo $CHALLENGE | NTLMParse
```

*Çıktı Analizi:*
```text
Signature: NTLMSSP
MessageType: 2 (Challenge)
TargetName: CORP
NegotiateFlags: 0x628a8205 (NegotiateUnicode, RequestTarget, NegotiateNTLM, NegotiateTargetInfo)
ServerChallenge: 3e0b301fab4f374d
TargetInfo:
  NetBIOS Domain: CORP
  NetBIOS Computer: EXCH01
  DNS Domain: corp.local
  DNS Computer: exch01.corp.local
OS Version: Windows Server 2019 (Major: 10, Minor: 0, Build: 17763)
```

---

## 4. Karşılaşılan Hatalar ve Çözümleri (Troubleshooting)

| Hata Mesajı | Olası Kök Neden | Çözüm Adımı |
|---|---|---|
| `Invalid NTLMSSP identifier` | Girdi NTLMSSP imzası ile başlamıyordur (`NTLMSSP\0` baytları eksiktir). | Başındaki `NTLM ` veya `Bearer ` ön eklerini kırpıp sadece Base64 metnini girin. |
| `Unsupported message type` | Mesaj Type 1, 2 veya 3 haricinde bozuk bir tür numarası içeriyordur. | Base64 dizgisinin tam kopyalandığından ve satır sonu boşluklarının kırpıldığından emin olun. |

---

## 5. OPSEC ve Karşı Tespit (IOC)

* **Sıfır İz (Zero-Footprint):** NTLMParse tamamen yerel ve çevrimdışı bir ayrıştırıcıdır; ağa hiçbir paket göndermez ve hedef sistemde hiçbir olay kaydı üretmez.
* **Pasif İstihbarat:** Dışarıya açık Exchange/IIS sunucularının iç Active Directory etki alanı adlarını ve DC adlarını sıfır yetkiyle ifşa etmekte kullanılır.

---

## 6. En Çok Kullanılan Komutlar (Cheat Sheet)

```bash
# 1. Base64 NTLM dizgisini doğrudan çözme
NTLMParse "TlRMTVNTUAACAAAADAAMADAAAAABAoEAASNFZ4mrZe8AAAAAAAAAAGIAYgA8AAAARABPAE0AQQBJAE4AAgAMAEQATwBNAEEASQBOAAEADABEAE8ATQBBAEkATgAEABYAZABvAG0AYQBpAG4ALgBsAG8AYwBhAGwAAwAmAGQAYwAwADEALgBkAG8AbQBhAGkAbgAuAGwAbwBjAGEAbAAAAAAA"

# 2. Curl çıktısını doğrudan NTLMParse'a yönlendirme
curl -s -k -I https://10.0.0.10/autodiscover/autodiscover.xml -H "Authorization: NTLM TlRMTVNTUAABAAAAB4IIogAAAAAAAAAAAAAAAAAAAAAGAbEdAAAADw==" | grep -i "www-authenticate: NTLM" | cut -d' ' -f3 | NTLMParse

# 3. Python tek satırlık alternatif NTLM decoder
python3 -c "import sys, base64; d=base64.b64decode(sys.argv[1]); print('Signature:', d[:8]); print('Type:', int.from_bytes(d[8:12], 'little'))" "TlRMTVNTUAAB..."
```

---

## Kaynaklar
- [GitHub — NTLMParse](https://github.com/praetorian-inc/ntlmparse)
- [Microsoft Open Specifications — MS-NLMP: NT LAN Manager (NTLM) Authentication Protocol](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-nlmp/)

---

> **Önceki:** [← nmap (NSE Script)](./nmap_NSE_Script.md) · **Sonraki:** [smbclient →](./smbclient.md)
