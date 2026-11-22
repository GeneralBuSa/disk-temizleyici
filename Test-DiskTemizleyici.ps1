# DiskTemizleyici.ps1 için testler. Gerçek dosyalara dokunmaz; %TEMP% altında sahte klasörlerle çalışır.
# Çalıştır: powershell -NoProfile -ExecutionPolicy Bypass -File .\Test-DiskTemizleyici.ps1
. "$PSScriptRoot\DiskTemizleyici.ps1" -NoRun
$T = Join-Path $env:TEMP 'DiskTemizleyiciTest'
$script:sonuc = @()
function Kontrol($ad, $kosul) { $script:sonuc += '{0,-6} {1}' -f $(if ($kosul) { 'GECTI' } else { 'KALDI' }), $ad }
function Var($n) { Test-Path "$T\$n" }
# Boyuta göre sıralanınca: 1 = C (3 MB), 2 = B (2 MB), 3 = A (1 MB)
function Hazirla {
    Remove-Item $T -Recurse -Force -ErrorAction SilentlyContinue
    $i = 1
    foreach ($n in 'a', 'b', 'c') {
        New-Item -ItemType Directory "$T\$n" -Force | Out-Null
        [IO.File]::WriteAllBytes("$T\$n\veri.bin", (New-Object byte[] ($i * 1MB))); $i++
    }
    $script:Adaylar.Clear()
    Add-Aday 'A' @("$T\a") 'GUVENLI' 'Test' 'x'
    Add-Aday 'B' @("$T\b") 'KONTROL' 'Test' 'x'
    Add-Aday 'C' @("$T\c") 'GUVENLI' 'Test' 'x'
}
function Cevaplar([string[]]$c) {
    $global:q = New-Object System.Collections.Queue; $c | ForEach-Object { $global:q.Enqueue($_) }
    $script:Sor = { param($m) if ($global:q.Count) { $global:q.Dequeue() } else { 'q' } }
}

Kontrol 'Seçim 1,3,5-7 -> 0,2,4,5,6' (((ConvertFrom-Secim '1,3,5-7' 10) -join ',') -eq '0,2,4,5,6')
Kontrol 'Tek başına 1 seçimi geçerli' ($null -ne (ConvertFrom-Secim '1' 3))
Kontrol 'Aralık dışı reddedilir' ($null -eq (ConvertFrom-Secim '11' 10))
Kontrol 'Harf reddedilir' ($null -eq (ConvertFrom-Secim 'abc' 10))
Kontrol 'WinGet korumalı' (Test-Korumali "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\x")
Kontrol 'Windows korumalı' (Test-Korumali "$env:windir\Installer")
Kontrol 'WinGetX korumalı sayılmaz' (-not (Test-Korumali "$env:LOCALAPPDATA\Microsoft\WinGetX"))
$script:Adaylar.Clear(); Add-Aday 'WG' @("$env:LOCALAPPDATA\Microsoft\WinGet") 'GUVENLI' 't' 't'
Kontrol 'Korumalı yol listeye eklenmez' ($script:Adaylar.Count -eq 0)

Hazirla; Cevaplar @('1-3', '2', 'hayir'); Invoke-Menu *> $null; Kontrol 'Onay "hayir" -> hiçbiri silinmedi' ((Var a) -and (Var b) -and (Var c))
Hazirla; Cevaplar @('1-3', '5');        Invoke-Menu *> $null; Kontrol 'Geçersiz yöntem -> iptal' ((Var a) -and (Var b) -and (Var c))
Hazirla; Cevaplar @('99');              Invoke-Menu *> $null; Kontrol 'Geçersiz seçim -> silinmedi' ((Var a) -and (Var b) -and (Var c))
Hazirla; Cevaplar @('g', '2', 'EVET');  Invoke-Menu *> $null; Kontrol 'g -> sadece GÜVENLİ (A,C) silindi' ((-not (Var a)) -and (Var b) -and (-not (Var c)))
Hazirla; Cevaplar @('1', '2', 'evet');  Invoke-Menu *> $null; Kontrol '1 -> sadece C kalıcı silindi' ((Var a) -and (Var b) -and (-not (Var c)))
Hazirla; Cevaplar @('2', '1', 'EVET');  Invoke-Menu *> $null; Kontrol '2 + Geri Dönüşüm -> sadece B kaldırıldı' ((Var a) -and (-not (Var b)) -and (Var c))
Hazirla; Cevaplar @('1', '2', 'EVET', '1', '2', 'EVET'); Invoke-Menu *> $null
Kontrol 'Silinen listeden çıkar, ikinci turda yeni 1 (B) silinir' ((Var a) -and (-not (Var b)) -and (-not (Var c)))

# --- Eski eklenti sürümleri
$eski = Get-EskiSurumler @('ms-python.python-2026.4.0-universal', 'ms-python.python-2026.2.0-universal',
                            'ms-python.python-2025.12.1-universal', 'golang.go-0.52.2-universal',
                            'meta.pyrefly-1.0.0-win32-x64', 'meta.pyrefly-1.0.0-linux-x64', 'bozukad')
$eskiAd = @($eski | ForEach-Object Ad | Sort-Object)
Kontrol 'Eklenti: aynı eklentinin 2 eski sürümü bulunur' ($eskiAd.Count -eq 2)
Kontrol 'Eklenti: en yeni sürüm (2026.4.0) eski sayılmaz' ($eskiAd -notcontains 'ms-python.python-2026.4.0-universal')
Kontrol 'Eklenti: 2025.12.1 < 2026.2.0 sayısal karşılaştırılır' ($eskiAd -contains 'ms-python.python-2025.12.1-universal')
Kontrol 'Eklenti: farklı platformlar ayrı sayılır' ($eskiAd -notcontains 'meta.pyrefly-1.0.0-win32-x64')
Kontrol 'Eklenti: tek sürümlü eklenti eski sayılmaz' ($eskiAd -notcontains 'golang.go-0.52.2-universal')

# --- Kullanılmayan Android sistem imajları
$sdk = "$T\sdk"; $avd = "$T\avd"
foreach ($i in 'android-33\google_apis_playstore\x86_64', 'android-36.1\google_apis_playstore\x86_64') { New-Item -ItemType Directory "$sdk\system-images\$i" -Force | Out-Null }
New-Item -ItemType Directory "$avd" -Force | Out-Null
$bos = Get-KullanilmayanImajlar $sdk $avd
Kontrol 'Android: hiç emülatör yoksa tüm imajlar kullanılmıyor' ($bos.Count -eq 2)
New-Item -ItemType Directory "$avd\Telefon.avd" -Force | Out-Null
Set-Content "$avd\Telefon.avd\config.ini" "hw.ramSize=2048`r`nimage.sysdir.1=system-images/android-33/google_apis_playstore/x86_64/"
$bos = Get-KullanilmayanImajlar $sdk $avd
Kontrol 'Android: emülatörün kullandığı imaj listelenmez' (($bos.Count -eq 1) -and ($bos[0] -like '*android-36.1*'))

# --- Program eşleştirme
$idx = @{ 'discord' = 'Discord'; 'thesims4' = 'The Sims 4 (Steam)'; 'riotgamesinc' = 'VALORANT (Riot Games, Inc)' }
Kontrol 'Eşleşme: birebir ad' ((Find-Eslesme 'Discord' $idx) -eq 'Discord')
Kontrol 'Eşleşme: ad, yayıncının içinde geçiyor' ((Find-Eslesme 'Riot Games' $idx) -like 'VALORANT*')
Kontrol 'Eşleşme: tanınmayan klasör $null döner' ($null -eq (Find-Eslesme 'EA SPORTS FC 26' $idx))
Kontrol 'Eşleşme: Türkçe karakter sadeleşir' ((Norm 'FMU Editör') -eq 'fmueditor')
$idx2 = [ordered]@{ 'microsoftvisualstudiocodeuser' = 'Microsoft Visual Studio Code (User)'; 'visualstudiocode' = 'VS Code (Store)'; 'mcpserver' = 'MCP Server' }
Kontrol 'Eşleşme: 3 harfli ad sadece birebir eşleşir (mcp)' ($null -eq (Find-Eslesme 'mcp' $idx2))
Kontrol 'Eşleşme: kısmi eşleşmede ilk eklenen (kayıt defteri) öncelikli' ((Find-Eslesme 'Code' $idx2) -eq 'Microsoft Visual Studio Code (User)')

# --- Etiketler: DOKUNMA öğeleri silme listesine girmez
$script:Adaylar.Clear(); $script:Bilgiler.Clear()
Add-Bilgi 'Deneme' 10MB 'açıklama'
Kontrol 'Bilgi öğesi varsayılan etiketi DOKUNMA' ($script:Bilgiler[0].Etiket -eq 'DOKUNMA')
Kontrol 'Bilgi öğesi silme listesine eklenmez' ($script:Adaylar.Count -eq 0)

Remove-Item $T -Recurse -Force -ErrorAction SilentlyContinue
$script:sonuc
$gecen = @($script:sonuc | Where-Object { $_ -like 'GECTI*' }).Count
"Toplam: $gecen/$($script:sonuc.Count)"
if ($gecen -ne $script:sonuc.Count) { exit 1 }
