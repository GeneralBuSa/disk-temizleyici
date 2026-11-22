<#
  DiskTemizleyici.ps1
  Bilgisayardaki gereksiz önbellekleri ve kaldırılmış programlardan kalan klasörleri bulur.
  HİÇBİR ŞEYİ KENDİLİĞİNDEN SİLMEZ: listeyi gösterir, kullanıcı seçer, "EVET" yazarak onaylar.

  Kullanım:
    .\DiskTemizleyici.ps1               # tara, listele, seçtiklerini onayla ve sil
    .\DiskTemizleyici.ps1 -SadeceRapor  # sadece tara ve listele, silme menüsü açılmaz
    .\DiskTemizleyici.ps1 -Csv rapor.csv  # listeyi ayrıca CSV olarak kaydet

  Not: Claude uygulamasının içindeki terminalde AppData sanallaştırılmış görünebilir.
  Normal bir PowerShell / Windows Terminal penceresinde çalıştır.
#>
param(
    [switch]$SadeceRapor,
    [string]$Csv,
    [switch]$NoRun   # testler için: fonksiyonları yükle, çalıştırma
)

try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
Add-Type -AssemblyName Microsoft.VisualBasic

$U = $env:USERPROFILE
$L = $env:LOCALAPPDATA
$R = $env:APPDATA
$PD = $env:ProgramData

# Kullanıcıdan girdi alma (testlerde değiştirilebilir)
$script:Sor = { param($mesaj) Read-Host $mesaj }

# ---------------------------------------------------------------- korumalı yollar
# Bu yollar ve altındaki her şey asla silme listesine girmez.
$script:Korumali = @(
    "$L\Microsoft\WinGet",                       # winget ile kurulan programların kendisi
    "$env:windir",                               # Windows (Installer önbelleği dahil)
    "$env:ProgramFiles\NVIDIA Corporation\Installer2",  # NVIDIA kaldırma/onarma dosyaları
    "$PD\LGHUB\depots",                          # G HUB'ın çalışan paketi
    "$R\uv",                                     # uv ayarları ve araçları
    "$U\.cache\codex-runtimes",
    "$U\.claude",
    "$L\Claude-Data", "$L\Claude", "$L\Claude-3p", "$R\Claude"
) | Where-Object { $_ }

function Test-Korumali([string]$yol) {
    $y = $yol.TrimEnd('\').ToLowerInvariant()
    foreach ($k in $script:Korumali) {
        $kk = $k.TrimEnd('\').ToLowerInvariant()
        if ($y -eq $kk -or $y.StartsWith($kk + '\')) { return $true }
    }
    if ($y -like "$($L.ToLowerInvariant())\packages\claude_*") { return $true }
    return $false
}

# ---------------------------------------------------------------- yardımcılar
function Get-Boyut([string[]]$yollar) {
    $t = [long]0
    foreach ($p in $yollar) {
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $i = Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
        if ($i -and -not $i.PSIsContainer) { $t += $i.Length; continue }
        $s = (Get-ChildItem -LiteralPath $p -Recurse -File -Force -ErrorAction SilentlyContinue |
              Measure-Object Length -Sum).Sum
        if ($s) { $t += [long]$s }
    }
    return $t
}

function Format-Boyut([long]$b) {
    if ($b -ge 1GB) { return '{0:N1} GB' -f ($b / 1GB) }
    if ($b -ge 1MB) { return '{0:N0} MB' -f ($b / 1MB) }
    if ($b -gt 0)   { return '{0:N0} KB' -f ($b / 1KB) }
    return '0'
}

function Norm([string]$s) {
    if (-not $s) { return '' }
    $s = $s.ToLowerInvariant() -replace 'ı', 'i' -replace 'ö', 'o' -replace 'ü', 'u' -replace 'ş', 's' -replace 'ç', 'c' -replace 'ğ', 'g'
    return ($s -replace '[^a-z0-9]', '')
}

$script:Adaylar = New-Object System.Collections.Generic.List[object]

function Add-Aday {
    param([string]$Ad, [string[]]$Yollar, [string]$Risk, [string]$Kategori, [string]$Not, [scriptblock]$Komut = $null)
    $Yollar = @($Yollar | Where-Object { $_ -and (Test-Path -LiteralPath $_) })
    if ($Yollar.Count -eq 0) { return }
    foreach ($y in $Yollar) { if (Test-Korumali $y) { Write-Verbose "Korumalı, atlandı: $y"; return } }
    $bayt = Get-Boyut $Yollar
    if ($Komut -and $bayt -lt 1MB) { return }   # zaten temiz önbellekleri gösterme
    $script:Adaylar.Add([pscustomobject]@{
        Ad = $Ad; Yollar = $Yollar; Bayt = $bayt
        Risk = $Risk; Kategori = $Kategori; Not = $Not; Komut = $Komut
    })
}

# ---------------------------------------------------------------- 1) önbellekler
function Find-Onbellekler {
    Write-Host '  Önbellekler taranıyor...' -ForegroundColor DarkGray

    if (Get-Command uv -ErrorAction SilentlyContinue) {
        $d = (& uv cache dir 2>$null); if (-not $d) { $d = "$L\uv\cache" }
        Add-Aday 'uv önbelleği' @($d) 'GUVENLI' 'Önbellek' 'uv cache clean ile temizlenir' { uv cache clean | Out-Host }
    }
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Add-Aday 'npm önbelleği' @("$L\npm-cache\_cacache") 'GUVENLI' 'Önbellek' 'npm cache clean ile temizlenir' { npm cache clean --force 2>&1 | Out-Null }
    }
    if (Get-Command python -ErrorAction SilentlyContinue) {
        Add-Aday 'pip önbelleği' @("$L\pip\cache") 'GUVENLI' 'Önbellek' 'pip cache purge ile temizlenir' { python -m pip cache purge | Out-Host }
    }
    Add-Aday 'Dart analiz önbelleği' @("$L\.dartServer") 'GUVENLI' 'Önbellek' 'Kendini yeniden oluşturur'
    Add-Aday 'Playwright tarayıcıları' @("$L\ms-playwright", "$L\ms-playwright-go") 'GUVENLI' 'Önbellek' 'Gerekirse playwright install ile yeniden iner'

    $dump = @(Get-ChildItem "$L\CrashDumps" -File -Force -ErrorAction SilentlyContinue | ForEach-Object FullName)
    if ($dump.Count) { Add-Aday "Çökme kayıtları ($($dump.Count) dosya)" $dump 'GUVENLI' 'Geçici' 'Programların çökme dökümleri' }

    $tw = @(Get-ChildItem $L -Directory -Force -Filter 'tw-*.tmp' -ErrorAction SilentlyContinue | ForEach-Object FullName)
    if ($tw.Count) { Add-Aday "Geçici tw-*.tmp klasörleri ($($tw.Count) adet)" $tw 'GUVENLI' 'Geçici' 'Boş geçici klasörler' }

    # Gradle: projelerde kullanılmayan sürümler
    $kullanilan = @{}
    $aramaYerleri = "$U\StudioProjects", "$U\Developer", "$U\Documents", "$U\Downloads", "$U\Desktop", "$U\source"
    Get-ChildItem $aramaYerleri -Recurse -Depth 6 -Filter gradle-wrapper.properties -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $line = Select-String -LiteralPath $_.FullName -Pattern 'distributionUrl' | Select-Object -First 1
        if ($line -and $line.Line -match 'gradle-([\d\.]+)-(all|bin)\.zip') { $kullanilan[$Matches[1]] = $true }
    }
    Get-ChildItem "$U\.gradle\caches" -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d+(\.\d+)+$' } | ForEach-Object {
            $v = $_.Name
            $yol = @($_.FullName) + @(Get-ChildItem "$U\.gradle\wrapper\dists" -Directory -Filter "gradle-$v-*" -ErrorAction SilentlyContinue | ForEach-Object FullName)
            if ($kullanilan.ContainsKey($v)) {
                Add-Aday "Gradle $v" $yol 'KONTROL' 'Önbellek' 'Bir projen bu sürümü kullanıyor; silinirse derlemede yeniden iner'
            } else {
                Add-Aday "Gradle $v" $yol 'GUVENLI' 'Önbellek' 'Bulunan projelerin hiçbiri bu sürümü kullanmıyor'
            }
        }

    # Eski Android Studio ayar klasörleri (en yeni sürüm hariç)
    foreach ($kok in "$L\Google", "$R\Google") {
        $as = @(Get-ChildItem $kok -Directory -Filter 'AndroidStudio*' -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^AndroidStudio(\d+(\.\d+)+)$' } |
                Sort-Object { [version]($_.Name -replace '^AndroidStudio', '') })
        if ($as.Count -gt 1) {
            $as[0..($as.Count - 2)] | ForEach-Object { Add-Aday "Eski Android Studio verisi ($($_.Name))" @($_.FullName) 'GUVENLI' 'Eski sürüm' "En yeni: $($as[-1].Name)" }
        }
    }

    # Android emülatörleri
    Get-ChildItem "$U\.android\avd" -Directory -Filter '*.avd' -ErrorAction SilentlyContinue | ForEach-Object {
        $ini = $_.FullName -replace '\.avd$', '.ini'
        Add-Aday "Android emülatörü ($($_.BaseName))" @($_.FullName, $ini) 'KONTROL' 'Emülatör' 'Silinirse Device Manager''dan yeniden oluşturman gerekir'
    }

    # NVIDIA App'in indirdiği sürücü paketleri
    $grd = "$PD\NVIDIA Corporation\NVIDIA App\UpdateFramework\ota-artifacts\grd"
    if (Test-Path $grd) {
        $kurulu = $null
        $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object Name -match 'NVIDIA' | Select-Object -First 1
        if ($gpu) { $d = $gpu.DriverVersion -replace '\.', ''; if ($d.Length -ge 5) { $s = $d.Substring($d.Length - 5); $kurulu = $s.Substring(0, 3) + '.' + $s.Substring(3) } }
        Get-ChildItem $grd -Directory -ErrorAction SilentlyContinue | Where-Object Name -ne 'post-processing' | ForEach-Object {
            $exe = Get-ChildItem $_.FullName -Filter *.exe -ErrorAction SilentlyContinue | Select-Object -First 1
            $ver = if ($exe -and $exe.Name -match '^(\d+\.\d+)') { $Matches[1] } else { '?' }
            $yol = @($_.FullName, "$grd\post-processing\$($_.Name)")
            if ($ver -eq $kurulu) {
                Add-Aday "NVIDIA sürücü paketi $ver" $yol 'GUVENLI' 'Kurulum dosyası' 'Bu sürüm zaten kurulu'
            } else {
                Add-Aday "NVIDIA sürücü paketi $ver" $yol 'KONTROL' 'Kurulum dosyası' "Kurulu sürüm: $kurulu. Bu paket kurulmamış; silinirse NVIDIA App yeniden indirebilir"
            }
        }
    }

    # Downloads: büyük kurulum dosyaları / arşivler (30 günden eski)
    $dl = "$U\Downloads"
    Get-ChildItem $dl -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -match '^\.(exe|msi|zip|rar|7z|iso)$' -and $_.Length -gt 50MB -and $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
        ForEach-Object {
            $not = 'Büyük kurulum dosyası veya arşiv'
            if ($_.Extension -match 'zip|rar|7z' -and (Test-Path (Join-Path $dl $_.BaseName))) { $not = 'Arşivin çıkarılmış hali yanında duruyor' }
            Add-Aday "Downloads: $($_.Name)" @($_.FullName) 'KONTROL' 'İndirilen dosya' $not
        }
}

# ---------------------------------------------------------------- 2) kurulu olmayan programların artıkları
function Get-KuruluIndeks {
    $t = New-Object System.Collections.Generic.HashSet[string]
    $ekle = { param($s) $n = Norm $s; if ($n.Length -ge 3) { [void]$t.Add($n) } }
    $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    foreach ($k in Get-ItemProperty $keys -ErrorAction SilentlyContinue) {
        foreach ($f in 'DisplayName', 'Publisher') { $p = $k.PSObject.Properties[$f]; if ($p -and $p.Value) { & $ekle $p.Value } }
        $p = $k.PSObject.Properties['InstallLocation']; if ($p -and $p.Value) { & $ekle (Split-Path $p.Value.TrimEnd('\') -Leaf) }
    }
    foreach ($d in "$env:ProgramFiles", "${env:ProgramFiles(x86)}", "$L\Programs") {
        Get-ChildItem $d -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            & $ekle $_.Name
            # üretici\ürün yapısı için bir alt seviye (örn. Electronic Arts\EA Desktop)
            Get-ChildItem $_.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object { & $ekle $_.Name }
        }
    }
    foreach ($a in Get-AppxPackage -ErrorAction SilentlyContinue) { $a.Name -split '\.' | ForEach-Object { & $ekle $_ }; & $ekle $a.Name }
    # Steam kütüphaneleri
    $vdf = "${env:ProgramFiles(x86)}\Steam\steamapps\libraryfolders.vdf"
    $kutup = @("${env:ProgramFiles(x86)}\Steam")
    if (Test-Path $vdf) { Select-String $vdf -Pattern '"path"\s+"(.+)"' | ForEach-Object { $kutup += ($_.Matches[0].Groups[1].Value -replace '\\\\', '\') } }
    foreach ($k in $kutup) { Get-ChildItem "$k\steamapps\common" -Directory -ErrorAction SilentlyContinue | ForEach-Object { & $ekle $_.Name } }
    # Epic
    Get-ChildItem "$PD\Epic\EpicGamesLauncher\Data\Manifests\*.item" -ErrorAction SilentlyContinue | ForEach-Object {
        try { & $ekle ((Get-Content $_.FullName -Raw | ConvertFrom-Json).DisplayName) } catch {}
    }
    Get-Process -ErrorAction SilentlyContinue | ForEach-Object { & $ekle $_.ProcessName }
    return $t
}

# Windows'un kendisine veya genel araçlara ait, artık sayılmaması gereken klasörler
$script:SistemKlasorleri = @(
    'Microsoft', 'Packages', 'Temp', 'Programs', 'Publishers', 'ConnectedDevicesPlatform', 'D3DSCache',
    'VirtualStore', 'Application Data', 'History', 'Temporary Internet Files', 'PlaceholderTileLogoFolder',
    'ToastNotificationManagerCompat', 'Package Cache', 'CrashDumps', 'SquirrelTemp', 'CEF', 'Sentry',
    'DataSharing', 'OEM', 'Intel', 'NVIDIA', 'NVIDIA Corporation', 'Google', 'Comms', 'Low', 'Microsoft Help',
    'IsolatedStorage', 'Macromedia', 'Sun', 'Mozilla', 'Apple', 'Apple Computer', 'Adobe', 'Backup', 'DBG',
    'Claude', 'Claude-Data', 'Claude-3p', 'claude-cli-nodejs', 'npm-cache', 'pip', 'uv', '.dartServer',
    'ms-playwright', 'ms-playwright-go', 'Android', 'npm', 'LocalLow',
    'BattlEye', 'EasyAntiCheat', 'EasyAntiCheat_EOS'   # birçok oyunun ortak kullandığı hile önleyiciler
)
# Klasör adı programın adından farklı olanlar: klasör -> kurulu programda aranacak isim
$script:TakmaAdlar = @{
    'TS4' = 'thesims4'; 'LGLData' = 'logitech'; 'FMUAsistan' = 'thefmu'
    'EADesktop' = 'eaapp'; 'Link2EA' = 'eaapp'; 'EALaunchHelper' = 'eaapp'
}

function Test-Eslesme([string]$ad, $idx) {
    $n = Norm $ad
    if ($n.Length -lt 3) { return $true }   # çok kısa isimlerde karar verme, artık sayma
    foreach ($t in $idx) {
        if ($t.Contains($n) -or ($n.Length -ge 4 -and $t.Length -ge 4 -and $n.Contains($t))) { return $true }
    }
    return $false
}
# Klasör adı -> varlığını kontrol edeceğimiz komut (geliştirici araçları)
$script:AracKlasorleri = @{
    'Pub' = 'dart'; 'Dart' = 'dart'; '.dart-tool' = 'dart'; '.flutter-devtools' = 'flutter'; 'kotlin' = 'kotlin'
    'GitHub CLI' = 'gh'; 'firebase' = 'firebase'; 'Python' = 'python'; 'pip-audit' = 'pip-audit'
    'create-next-app-nodejs' = 'node'; 'nextjs-nodejs' = 'node'; 'ffmpeg-static-nodejs' = 'node'; 'main.kts.compiled.cache' = 'kotlin'
}

function Find-Artiklar {
    Write-Host '  Kurulu programlar okunuyor...' -ForegroundColor DarkGray
    $idx = Get-KuruluIndeks
    Write-Host '  AppData klasörleri kurulu programlarla karşılaştırılıyor...' -ForegroundColor DarkGray
    foreach ($bolge in 'Local', 'LocalLow', 'Roaming') {
        Get-ChildItem "$U\AppData\$bolge" -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $ad = $_.Name
            if ($script:SistemKlasorleri -contains $ad) { return }
            if ($ad -like 'tw-*.tmp' -or $ad -like 'cbm-daemon-*') { return }
            if ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) { return }
            if ($script:AracKlasorleri.ContainsKey($ad)) {
                if (-not (Get-Command $script:AracKlasorleri[$ad] -ErrorAction SilentlyContinue)) {
                    Add-Aday "$bolge\$ad" @($_.FullName) 'KONTROL' 'Artık' "İlgili araç ($($script:AracKlasorleri[$ad])) bulunamadı"
                }
                return
            }
            $bulundu = Test-Eslesme $ad $idx
            if (-not $bulundu -and $script:TakmaAdlar.ContainsKey($ad)) { $bulundu = Test-Eslesme $script:TakmaAdlar[$ad] $idx }
            if (-not $bulundu) {
                # Şirket\Oyun yapısı (özellikle LocalLow): alt klasörlerden biri kurulu bir programsa artık değildir
                foreach ($alt in Get-ChildItem -LiteralPath $_.FullName -Directory -Force -ErrorAction SilentlyContinue) {
                    if (Test-Eslesme $alt.Name $idx) { $bulundu = $true; break }
                }
            }
            if (-not $bulundu) {
                Add-Aday "$bolge\$ad" @($_.FullName) 'KONTROL' 'Artık' 'Kurulu bir programla eşleşmedi; içinde oyun kaydı/ayar olabilir'
            }
        }
    }
}

# ---------------------------------------------------------------- liste, seçim, silme
function Show-Liste($liste) {
    Write-Host ''
    Write-Host ('{0,3}  {1,-9} {2,9}  {3}' -f 'No', 'Durum', 'Boyut', 'Ad / Not') -ForegroundColor White
    Write-Host ('-' * 90)
    for ($i = 0; $i -lt $liste.Count; $i++) {
        $a = $liste[$i]
        $renk = if ($a.Risk -eq 'GUVENLI') { 'Green' } else { 'Yellow' }
        $etiket = if ($a.Risk -eq 'GUVENLI') { 'GÜVENLİ' } else { 'KONTROL' }
        Write-Host ('{0,3}  ' -f ($i + 1)) -NoNewline
        Write-Host ('{0,-9}' -f $etiket) -ForegroundColor $renk -NoNewline
        Write-Host (' {0,9}  {1}' -f (Format-Boyut $a.Bayt), $a.Ad)
        Write-Host ('                         {0}' -f $a.Not) -ForegroundColor DarkGray
    }
    $g = ($liste | Where-Object Risk -eq 'GUVENLI' | Measure-Object Bayt -Sum).Sum
    $k = ($liste | Where-Object Risk -eq 'KONTROL' | Measure-Object Bayt -Sum).Sum
    Write-Host ('-' * 90)
    Write-Host ("GÜVENLİ toplam: {0}    KONTROL toplam: {1}" -f (Format-Boyut ([long]$g)), (Format-Boyut ([long]$k)))
}

# "1,3,5-7" -> 0 tabanlı indeksler; geçersizse $null
function ConvertFrom-Secim([string]$metin, [int]$adet) {
    $sonuc = New-Object System.Collections.Generic.List[int]
    foreach ($parca in ($metin -split '[,\s]+' | Where-Object { $_ })) {
        if ($parca -match '^(\d+)-(\d+)$') { $a = [int]$Matches[1]; $b = [int]$Matches[2] }
        elseif ($parca -match '^\d+$') { $a = [int]$parca; $b = $a }
        else { return $null }
        if ($a -lt 1 -or $b -gt $adet -or $a -gt $b) { return $null }
        for ($i = $a; $i -le $b; $i++) { if (-not $sonuc.Contains($i - 1)) { $sonuc.Add($i - 1) } }
    }
    if ($sonuc.Count -eq 0) { return $null }
    return , $sonuc.ToArray()
}

function Remove-Aday($a, [bool]$geriDonusum) {
    if ($a.Komut) {
        & $a.Komut
    } else {
        foreach ($y in $a.Yollar) {
            if (Test-Korumali $y) { Write-Host "  Korumalı yol, atlandı: $y" -ForegroundColor Red; continue }
            if (-not (Test-Path -LiteralPath $y)) { continue }
            try {
                $oge = Get-Item -LiteralPath $y -Force
                if ($geriDonusum) {
                    if ($oge.PSIsContainer) { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($y, 'OnlyErrorDialogs', 'SendToRecycleBin') }
                    else { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($y, 'OnlyErrorDialogs', 'SendToRecycleBin') }
                } else {
                    Remove-Item -LiteralPath $y -Recurse -Force -ErrorAction Stop
                }
            } catch { Write-Host "  Hata: $y -> $($_.Exception.Message)" -ForegroundColor Red }
        }
    }
    # Doğrulama
    $kalan = @($a.Yollar | Where-Object { Test-Path -LiteralPath $_ })
    if ($a.Komut) { $kalanBayt = Get-Boyut $a.Yollar; return ($kalanBayt -lt [math]::Max(1MB, $a.Bayt * 0.05)) }
    return ($kalan.Count -eq 0)
}

function Invoke-Menu {
    $liste = @($script:Adaylar | Sort-Object Bayt -Descending)
    while ($liste.Count -gt 0) {
        Show-Liste $liste
        Write-Host ''
        Write-Host 'Seçim: numaralar (örn. 1,3,5-7)  |  g = tüm GÜVENLİ olanlar  |  q = çıkış'
        $girdi = (& $script:Sor 'Seçimin').Trim()
        if ($girdi -match '^(q|ç|cik|çık)$' -or $girdi -eq '') { break }
        if ($girdi -eq 'g') {
            $idx = @(for ($i = 0; $i -lt $liste.Count; $i++) { if ($liste[$i].Risk -eq 'GUVENLI') { $i } })
            if ($idx.Count -eq 0) { Write-Host 'GÜVENLİ öğe yok.' -ForegroundColor Yellow; continue }
        } else {
            $idx = ConvertFrom-Secim $girdi $liste.Count
            # Not: "-not $idx" kullanma; tek elemanlı @(0) dizisi PowerShell'de false sayılır
            if ($null -eq $idx) { Write-Host 'Geçersiz seçim.' -ForegroundColor Red; continue }
        }
        $secilen = @($idx | ForEach-Object { $liste[$_] })
        $toplam = [long](($secilen | Measure-Object Bayt -Sum).Sum)

        Write-Host ''
        Write-Host 'Silinecekler:' -ForegroundColor White
        foreach ($a in $secilen) {
            Write-Host ('  - {0}  ({1})' -f $a.Ad, (Format-Boyut $a.Bayt))
            foreach ($y in ($a.Yollar | Select-Object -First 3)) { Write-Host "      $y" -ForegroundColor DarkGray }
            if ($a.Yollar.Count -gt 3) { Write-Host "      ... ve $($a.Yollar.Count - 3) yol daha" -ForegroundColor DarkGray }
            if ($a.Komut) { Write-Host '      (kendi temizleme komutuyla, kalıcı olarak)' -ForegroundColor DarkGray }
        }
        Write-Host ("Toplam: {0}" -f (Format-Boyut $toplam)) -ForegroundColor White

        $yontem = (& $script:Sor 'Nasıl silinsin? 1 = Geri Dönüşüm Kutusu (geri alınabilir, yer açmaz)  2 = Kalıcı sil').Trim()
        if ($yontem -ne '1' -and $yontem -ne '2') { Write-Host 'İptal edildi.' -ForegroundColor Yellow; continue }
        $geri = ($yontem -eq '1')
        $onay = (& $script:Sor ("Onaylıyor musun? Devam etmek için EVET yaz ({0})" -f $(if ($geri) { 'Geri Dönüşüm Kutusu' } else { 'KALICI' }))).Trim()
        if ($onay.ToUpperInvariant() -ne 'EVET') { Write-Host 'Onay verilmedi, hiçbir şey silinmedi.' -ForegroundColor Yellow; continue }

        $bosOnce = (Get-PSDrive C).Free
        foreach ($a in $secilen) {
            Write-Host "Siliniyor: $($a.Ad)..." -NoNewline
            if (Remove-Aday $a $geri) { Write-Host ' TAMAM' -ForegroundColor Green }
            else { Write-Host ' KISMEN (bazı dosyalar kilitli olabilir; programı kapatıp ya da yönetici olarak tekrar dene)' -ForegroundColor Yellow }
        }
        $fark = (Get-PSDrive C).Free - $bosOnce
        Write-Host ("C: sürücüsünde açılan yer: {0}" -f (Format-Boyut ([long][math]::Max(0, $fark)))) -ForegroundColor Cyan
        $liste = @($liste | Where-Object { $secilen -notcontains $_ })
    }
    Write-Host 'Çıkılıyor.'
}

function Start-Temizleyici {
    Write-Host 'Disk Temizleyici - hiçbir şey onayın olmadan silinmez.' -ForegroundColor Cyan
    Write-Host 'Taranıyor (birkaç dakika sürebilir)...'
    $script:Adaylar.Clear()
    Find-Onbellekler
    Find-Artiklar
    if ($script:Adaylar.Count -eq 0) { Write-Host 'Temizlenecek bir şey bulunamadı.'; return }
    if ($Csv) {
        $script:Adaylar | Sort-Object Bayt -Descending |
            Select-Object Ad, Risk, Kategori, @{n = 'MB'; e = { [math]::Round($_.Bayt / 1MB, 1) } }, Not, @{n = 'Yollar'; e = { $_.Yollar -join ' | ' } } |
            Export-Csv $Csv -NoTypeInformation -Encoding UTF8
        Write-Host "Rapor kaydedildi: $Csv"
    }
    if ($SadeceRapor) { Show-Liste @($script:Adaylar | Sort-Object Bayt -Descending); return }
    Invoke-Menu
}

if (-not $NoRun) { Start-Temizleyici }
