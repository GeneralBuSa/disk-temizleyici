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

Remove-Item $T -Recurse -Force -ErrorAction SilentlyContinue
$script:sonuc
$gecen = @($script:sonuc | Where-Object { $_ -like 'GECTI*' }).Count
"Toplam: $gecen/$($script:sonuc.Count)"
if ($gecen -ne $script:sonuc.Count) { exit 1 }
