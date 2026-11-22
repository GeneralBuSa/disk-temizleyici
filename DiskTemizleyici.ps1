<#
  DiskTemizleyici.ps1
  Bilgisayardaki önbellekleri, eski sürüm dosyalarını ve kaldırılmış programlardan kalan
  klasörleri bulur. Taradığı her şeyi listeler ve yanına tarafsız bir etiket koyar:
    GÜVENLİ    : kendini yeniden oluşturan / zaten kullanılmış dosyalar
    KONTROL ET : ne olduğuna kullanıcının bakması gereken dosyalar
    DOKUNMA    : silinirse bir programı veya Windows'u bozabilecek dosyalar (silme listesine hiç girmez)
  Program öneri vermez; silme kararı ve sorumluluğu kullanıcıya aittir.
  HİÇBİR ŞEYİ KENDİLİĞİNDEN SİLMEZ: kullanıcı seçer, "EVET" yazarak onaylar.

  Kullanım:
    .\DiskTemizleyici.ps1                 # tara, raporla, seçtiklerini onayla ve sil
    .\DiskTemizleyici.ps1 -SadeceRapor    # sadece tara ve raporla, silme menüsü açılmaz
    .\DiskTemizleyici.ps1 -Csv rapor.csv  # raporu CSV olarak da kaydet

  Not: Bazı uygulamaların (MSIX paketli) içindeki terminallerde AppData sanallaştırılmış
  görünebilir. Normal bir PowerShell / Windows Terminal penceresinde çalıştır.
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
$SD = $env:SystemDrive

# Kullanıcıdan girdi alma (testlerde değiştirilebilir)
$script:Sor = { param($mesaj) Read-Host $mesaj }

# ================================================================ korumalı yollar
# Bu yollar ve altındaki her şey asla silme listesine girmez.
$script:Korumali = @(
    "$L\Microsoft\WinGet",                       # winget ile kurulan programların kendisi
    "$env:windir",                               # Windows (Installer önbelleği dahil)
    "$env:ProgramFiles\WindowsApps",             # Store uygulamalarının kendisi
    "$env:ProgramFiles\NVIDIA Corporation\Installer2",  # NVIDIA kaldırma/onarma dosyaları
    "$PD\LGHUB\depots",                          # G HUB'ın çalışan paketi
    "$R\uv",                                     # uv ayarları ve araçları
    "$U\.cache\codex-runtimes",
    "$U\.claude",
    "$env:TEMP\claude",
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

# ================================================================ yardımcılar
$script:BoyutHafiza = @{}

# Klasör boyutunu hızlı ölçer (Get-ChildItem'dan kat kat hızlı). Erişilemeyen klasörleri atlar,
# bağlantı noktalarını (junction/symlink) izlemez, böylece aynı dosya iki kez sayılmaz.
if (-not ('DiskTemizleyiciBoyut' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;
public static class DiskTemizleyiciBoyut {
    public static long Hesapla(string yol) {
        long toplam = 0;
        var yigin = new Stack<string>();
        yigin.Push(yol);
        while (yigin.Count > 0) {
            string d = yigin.Pop();
            DirectoryInfo di;
            try { di = new DirectoryInfo(d); } catch { continue; }
            try { foreach (var f in di.EnumerateFiles()) { try { toplam += f.Length; } catch { } } } catch { }
            try {
                foreach (var s in di.EnumerateDirectories()) {
                    if ((s.Attributes & FileAttributes.ReparsePoint) == 0) yigin.Push(s.FullName);
                }
            } catch { }
        }
        return toplam;
    }

    // Belirli bir dosyayı en fazla maxDerinlik seviye arar. node_modules, .git, sanal ortamlar gibi
    // dev klasörlere girmez (proje aramasını dakikalardan saniyelere indirir).
    static readonly HashSet<string> Atla = new HashSet<string>(StringComparer.OrdinalIgnoreCase) {
        "node_modules", ".git", ".venv", "venv", "env", "__pycache__", "site-packages", ".gradle", "build",
        ".dart_tool", ".idea", ".vs", "bin", "obj", "dist", "out", "target", ".next", ".cache", "Library", "Pods"
    };
    public static List<string> DosyaBul(string kok, string dosyaAdi, int maxDerinlik) {
        var sonuc = new List<string>();
        if (!Directory.Exists(kok)) return sonuc;
        var yigin = new Stack<KeyValuePair<string, int>>();
        yigin.Push(new KeyValuePair<string, int>(kok, 0));
        while (yigin.Count > 0) {
            var o = yigin.Pop();
            try {
                string f = Path.Combine(o.Key, dosyaAdi);
                if (File.Exists(f)) sonuc.Add(f);
                if (o.Value >= maxDerinlik) continue;
                foreach (var s in new DirectoryInfo(o.Key).EnumerateDirectories()) {
                    if ((s.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                    if (Atla.Contains(s.Name)) continue;
                    yigin.Push(new KeyValuePair<string, int>(s.FullName, o.Value + 1));
                }
            } catch { }
        }
        return sonuc;
    }
}
'@
}

function Get-Boyut([string[]]$yollar, [switch]$Taze) {
    $t = [long]0
    foreach ($p in $yollar) {
        if (-not $Taze -and $script:BoyutHafiza.ContainsKey($p)) { $t += $script:BoyutHafiza[$p]; continue }
        $b = [long]0
        if (Test-Path -LiteralPath $p) {
            $i = Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
            if ($i -and -not $i.PSIsContainer) { $b = $i.Length }
            elseif ($i) { $b = [DiskTemizleyiciBoyut]::Hesapla($i.FullName) }
        }
        $script:BoyutHafiza[$p] = $b
        $t += $b
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

function Test-Yonetici {
    try { return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
    catch { return $false }
}

$script:Adaylar   = New-Object System.Collections.Generic.List[object]   # silinebilecekler
$script:Envanter  = New-Object System.Collections.Generic.List[object]   # taranan her AppData klasörü
$script:Bilgiler  = New-Object System.Collections.Generic.List[object]   # taranan ama silme listesine alınmayanlar
$script:Istatistik = @{ Kayit = 0; Store = 0; Steam = 0; Epic = 0 }

function Add-Aday {
    param([string]$Ad, [string[]]$Yollar, [string]$Risk, [string]$Kategori, [string]$Not, [scriptblock]$Komut = $null)
    $Yollar = @($Yollar | Where-Object { $_ -and (Test-Path -LiteralPath $_) })
    if ($Yollar.Count -eq 0) { return }
    foreach ($y in $Yollar) { if (Test-Korumali $y) { Write-Verbose "Korumalı, atlandı: $y"; return } }
    foreach ($a in $script:Adaylar) { foreach ($y in $Yollar) { if ($a.Yollar -contains $y) { return } } }  # aynı yol iki kez listelenmesin
    $bayt = Get-Boyut $Yollar
    if ($Komut -and $bayt -lt 1MB) { return }                 # zaten temiz önbellekleri gösterme
    if ($bayt -eq 0 -and $Kategori -eq 'Önbellek') { return } # boş önbellekleri gösterme
    $script:Adaylar.Add([pscustomobject]@{
        Ad = $Ad; Yollar = $Yollar; Bayt = $bayt
        Risk = $Risk; Kategori = $Kategori; Not = $Not; Komut = $Komut
    })
}

function Add-Bilgi([string]$Ad, [long]$Bayt, [string]$Aciklama, [string]$Etiket = 'DOKUNMA') {
    $script:Bilgiler.Add([pscustomobject]@{ Ad = $Ad; Bayt = $Bayt; Etiket = $Etiket; Aciklama = $Aciklama })
}

# ================================================================ saf yardımcı mantık (testli)

# Eklenti klasör adlarından (yayinci.ad-1.2.3[-platform]) eski sürümleri döndürür.
function Get-EskiSurumler([string[]]$adlar) {
    $gruplar = @{}
    foreach ($a in $adlar) {
        if ($a -match '^(?<id>.+?)-(?<ver>\d+(\.\d+){1,3})(-(?<plat>[a-z0-9\-]+))?$') {
            $anahtar = $Matches['id'] + '|' + $Matches['plat']
            try { $v = [version]$Matches['ver'] } catch { continue }
            if (-not $gruplar.ContainsKey($anahtar)) { $gruplar[$anahtar] = New-Object System.Collections.Generic.List[object] }
            $gruplar[$anahtar].Add([pscustomobject]@{ Ad = $a; V = $v })
        }
    }
    $eski = New-Object System.Collections.Generic.List[object]
    foreach ($g in $gruplar.Values) {
        if ($g.Count -lt 2) { continue }
        $sirali = @($g | Sort-Object V)
        $enYeni = $sirali[-1].Ad
        for ($i = 0; $i -lt $sirali.Count - 1; $i++) { $eski.Add([pscustomobject]@{ Ad = $sirali[$i].Ad; EnYeni = $enYeni }) }
    }
    return , $eski.ToArray()
}

# Android SDK'da hiçbir emülatörün (AVD) kullanmadığı sistem imajlarını döndürür.
function Get-KullanilmayanImajlar([string]$sdk, [string]$avdKlasoru) {
    $kullanilan = @{}
    Get-ChildItem -LiteralPath $avdKlasoru -Directory -Filter '*.avd' -ErrorAction SilentlyContinue | ForEach-Object {
        $cfg = Join-Path $_.FullName 'config.ini'
        if (Test-Path -LiteralPath $cfg) {
            Select-String -LiteralPath $cfg -Pattern '^image\.sysdir\.\d+\s*=\s*(.+)$' | ForEach-Object {
                $kullanilan[(($_.Matches[0].Groups[1].Value.Trim() -replace '/', '\').TrimEnd('\')).ToLowerInvariant()] = $true
            }
        }
    }
    $sonuc = New-Object System.Collections.Generic.List[string]
    $kok = Join-Path $sdk 'system-images'
    # system-images\<api>\<tag>\<abi>
    Get-ChildItem -LiteralPath $kok -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Get-ChildItem -LiteralPath $_.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Get-ChildItem -LiteralPath $_.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $goreli = $_.FullName.Substring($sdk.TrimEnd('\').Length + 1).ToLowerInvariant()
                if (-not $kullanilan.ContainsKey($goreli)) { $sonuc.Add($_.FullName) }
            }
        }
    }
    return , $sonuc.ToArray()
}

# ================================================================ 1) önbellekler ve eski sürümler
$script:UygulamaOnbellekAdlari = 'Cache', 'Code Cache', 'GPUCache', 'CachedData', 'Crashpad', 'DawnCache',
    'DawnGraphiteCache', 'DawnWebGPUCache', 'GrShaderCache', 'ShaderCache', 'CachedExtensionVSIXs', 'component_crx_cache'

function Add-UygulamaOnbellegi([string]$ad, [string]$kok) {
    if (-not (Test-Path -LiteralPath $kok)) { return }
    $yollar = New-Object System.Collections.Generic.List[string]
    foreach ($n in $script:UygulamaOnbellekAdlari) { $p = Join-Path $kok $n; if (Test-Path -LiteralPath $p) { $yollar.Add($p) } }
    # Chromium profilleri (Default, Profile 1, ...)
    Get-ChildItem -LiteralPath $kok -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' } | ForEach-Object {
            foreach ($n in 'Cache', 'Code Cache', 'GPUCache') { $p = Join-Path $_.FullName $n; if (Test-Path -LiteralPath $p) { $yollar.Add($p) } }
        }
    if ($yollar.Count -eq 0) { return }
    if ((Get-Boyut $yollar.ToArray()) -lt 20MB) { return }
    Add-Aday "Önbellek: $ad" $yollar.ToArray() 'GUVENLI' 'Uygulama önbelleği' 'Kendini yeniden oluşturur. Program açıkken bazı dosyalar kilitli olabilir'
}

function Find-Onbellekler {
    Write-Host '  Geliştirici araçlarının önbellekleri...' -ForegroundColor DarkGray
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
    if (Get-Command yarn -ErrorAction SilentlyContinue) {
        Add-Aday 'Yarn önbelleği' @("$L\Yarn\Cache") 'GUVENLI' 'Önbellek' 'yarn cache clean ile temizlenir' { yarn cache clean 2>&1 | Out-Null }
    }
    if (Get-Command go -ErrorAction SilentlyContinue) {
        $gc = (& go env GOCACHE 2>$null)
        if ($gc) { Add-Aday 'Go derleme önbelleği' @($gc) 'GUVENLI' 'Önbellek' 'go clean -cache ile temizlenir' { go clean -cache } }
    }
    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        Add-Aday 'NuGet paket önbelleği' @("$U\.nuget\packages") 'KONTROL' 'Önbellek' '.NET projeleri bir sonraki derlemede paketleri yeniden indirir' { dotnet nuget locals all --clear | Out-Host }
    }
    Add-Aday 'Dart analiz önbelleği' @("$L\.dartServer") 'GUVENLI' 'Önbellek' 'Kendini yeniden oluşturur'
    Add-Aday 'Playwright tarayıcıları' @("$L\ms-playwright", "$L\ms-playwright-go") 'GUVENLI' 'Önbellek' 'Gerekirse playwright install ile yeniden iner'

    Write-Host '  Geçici dosyalar ve çökme kayıtları...' -ForegroundColor DarkGray
    $dump = @(Get-ChildItem "$L\CrashDumps" -File -Force -ErrorAction SilentlyContinue | ForEach-Object FullName)
    if ($dump.Count) { Add-Aday "Çökme kayıtları ($($dump.Count) dosya)" $dump 'GUVENLI' 'Geçici' 'Programların çökme dökümleri' }

    $tw = @(Get-ChildItem $L -Directory -Force -Filter 'tw-*.tmp' -ErrorAction SilentlyContinue | ForEach-Object FullName)
    if ($tw.Count) { Add-Aday "Geçici tw-*.tmp klasörleri ($($tw.Count) adet)" $tw 'GUVENLI' 'Geçici' 'Boş geçici klasörler' }

    $sinir = (Get-Date).AddDays(-7)
    $eskiTemp = @(Get-ChildItem $env:TEMP -Force -ErrorAction SilentlyContinue |
                  Where-Object { $_.LastWriteTime -lt $sinir -and -not (Test-Korumali $_.FullName) } | ForEach-Object FullName)
    if ($eskiTemp.Count) { Add-Aday "Eski geçici dosyalar ($($eskiTemp.Count) öğe)" $eskiTemp 'GUVENLI' 'Geçici' '%TEMP% içinde 7 günden eski dosya ve klasörler' }

    Write-Host '  Tarayıcı ve uygulama önbellekleri...' -ForegroundColor DarkGray
    $tarayicilar = [ordered]@{
        'Google Chrome' = "$L\Google\Chrome\User Data"
        'Microsoft Edge' = "$L\Microsoft\Edge\User Data"
        'Brave' = "$L\BraveSoftware\Brave-Browser\User Data"
        'Opera GX (Local)' = "$L\Opera Software\Opera GX Stable"
        'Opera GX (Roaming)' = "$R\Opera Software\Opera GX Stable"
        'Opera' = "$L\Opera Software\Opera Stable"
        'Vivaldi' = "$L\Vivaldi\User Data"
    }
    foreach ($k in $tarayicilar.Keys) { Add-UygulamaOnbellegi $k $tarayicilar[$k] }
    $ff = @(Get-ChildItem "$L\Mozilla\Firefox\Profiles\*\cache2" -Directory -ErrorAction SilentlyContinue | ForEach-Object FullName)
    if ($ff.Count -and (Get-Boyut $ff) -ge 20MB) { Add-Aday 'Önbellek: Firefox' $ff 'GUVENLI' 'Uygulama önbelleği' 'Kendini yeniden oluşturur. Firefox açıkken bazı dosyalar kilitli olabilir' }
    # Electron uygulamaları (Discord, VS Code, Cursor, Teams...): Roaming ve Local altındaki üst klasörler
    foreach ($kok in $R, $L) {
        Get-ChildItem $kok -Directory -Force -ErrorAction SilentlyContinue | Where-Object {
            -not (Test-Korumali $_.FullName) -and $_.Name -ne 'Packages' -and
            ((Test-Path -LiteralPath (Join-Path $_.FullName 'Code Cache')) -or (Test-Path -LiteralPath (Join-Path $_.FullName 'GPUCache')))
        } | ForEach-Object { Add-UygulamaOnbellegi $_.Name $_.FullName }
    }

    Write-Host '  Editör eklentilerinin eski sürümleri...' -ForegroundColor DarkGray
    Get-ChildItem $U -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\.(vscode|vscode-insiders|cursor|windsurf|antigravity.*|kiro|trae)$' } | ForEach-Object {
            $ext = Join-Path $_.FullName 'extensions'
            if (-not (Test-Path -LiteralPath $ext)) { return }
            $editor = $_.Name.TrimStart('.')
            $adlar = @(Get-ChildItem -LiteralPath $ext -Directory -ErrorAction SilentlyContinue | ForEach-Object Name)
            $eski = Get-EskiSurumler $adlar
            if ($eski.Count) {
                $yollar = @($eski | ForEach-Object { Join-Path $ext $_.Ad })
                Add-Aday "Eski eklenti sürümleri: $editor ($($eski.Count) adet)" $yollar 'GUVENLI' 'Eski sürüm' 'Aynı eklentinin daha yeni sürümü kurulu. Editör açıkken dosyalar kilitli olabilir'
            }
        }

    Write-Host '  Gradle, Android ve NVIDIA...' -ForegroundColor DarkGray
    # Gradle: projelerde kullanılmayan sürümler
    $kullanilan = @{}
    $aramaYerleri = "$U\StudioProjects", "$U\Developer", "$U\Documents", "$U\Downloads", "$U\Desktop", "$U\source", "$U\Projects"
    @(foreach ($yer in $aramaYerleri) { [DiskTemizleyiciBoyut]::DosyaBul($yer, 'gradle\wrapper\gradle-wrapper.properties', 6) }) | ForEach-Object {
        $line = Select-String -LiteralPath $_ -Pattern 'distributionUrl' | Select-Object -First 1
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

    # Android SDK: emülatörler, kullanılmayan sistem imajları, eski NDK'lar
    $avdKlasoru = "$U\.android\avd"
    $avdler = @(Get-ChildItem $avdKlasoru -Directory -Filter '*.avd' -ErrorAction SilentlyContinue)
    foreach ($a in $avdler) {
        $ini = $a.FullName -replace '\.avd$', '.ini'
        Add-Aday "Android emülatörü ($($a.BaseName))" @($a.FullName, $ini) 'KONTROL' 'Emülatör' 'Silinirse Device Manager''dan yeniden oluşturman gerekir'
    }
    $sdk = if ($env:ANDROID_HOME -and (Test-Path $env:ANDROID_HOME)) { $env:ANDROID_HOME } else { "$L\Android\Sdk" }
    if (Test-Path $sdk) {
        foreach ($img in (Get-KullanilmayanImajlar $sdk $avdKlasoru)) {
            $ad = $img.Substring($sdk.TrimEnd('\').Length + 1) -replace '^system-images\\', ''
            Add-Aday "Android sistem imajı ($ad)" @($img) 'GUVENLI' 'Emülatör' 'Hiçbir emülatör bu imajı kullanmıyor; derleme için gerekmez'
        }
        if ($avdler.Count -eq 0) {
            Add-Aday 'Android emülatör programı' @("$sdk\emulator") 'GUVENLI' 'Emülatör' 'Hiç emülatörün yok; gerekirse Android Studio yeniden indirir'
        }
        $ndk = @(Get-ChildItem "$sdk\ndk" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d+(\.\d+)+$' } | Sort-Object { [version]$_.Name })
        if ($ndk.Count -gt 1) {
            $ndk[0..($ndk.Count - 2)] | ForEach-Object { Add-Aday "Eski Android NDK ($($_.Name))" @($_.FullName) 'KONTROL' 'Eski sürüm' "En yeni: $($ndk[-1].Name). Projen eski sürümü sabitlemişse gerekir" }
        }
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
    Add-Aday 'NVIDIA shader önbelleği' @("$L\NVIDIA\DXCache", "$L\NVIDIA\GLCache") 'KONTROL' 'Önbellek' 'Oyunlar ilk açılışta takılır ve önbellek kısa sürede geri dolar'
    Add-Aday 'Logitech G HUB güncelleme önbelleği' @("$PD\LGHUB\cache") 'KONTROL' 'Önbellek' 'G HUB''ın indirdiği güncelleme kopyası'

    # Steam shader önbellekleri (tüm kütüphaneler)
    foreach ($k in (Get-SteamKutuphaneleri)) {
        Add-Aday "Steam shader önbelleği ($k)" @("$k\steamapps\shadercache") 'KONTROL' 'Önbellek' 'Oyunlar ilk açılışta shader derler'
    }

    Write-Host '  Downloads klasörü...' -ForegroundColor DarkGray
    $dl = "$U\Downloads"
    Get-ChildItem $dl -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -match '^\.(exe|msi|zip|rar|7z|iso)$' -and $_.Length -gt 50MB -and $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
        ForEach-Object {
            $not = 'Büyük kurulum dosyası veya arşiv'
            if ($_.Extension -match 'zip|rar|7z' -and (Test-Path (Join-Path $dl $_.BaseName))) { $not = 'Arşivin çıkarılmış hali yanında duruyor' }
            Add-Aday "Downloads: $($_.Name)" @($_.FullName) 'KONTROL' 'İndirilen dosya' $not
        }
}

function Get-SteamKutuphaneleri {
    $kutup = New-Object System.Collections.Generic.List[string]
    $steam = "${env:ProgramFiles(x86)}\Steam"
    if (Test-Path $steam) { $kutup.Add($steam) }
    $vdf = "$steam\steamapps\libraryfolders.vdf"
    if (Test-Path $vdf) {
        Select-String $vdf -Pattern '"path"\s+"(.+)"' | ForEach-Object {
            $p = $_.Matches[0].Groups[1].Value -replace '\\\\', '\'
            if ((Test-Path $p) -and -not ($kutup | Where-Object { $_ -eq $p })) { $kutup.Add($p) }
        }
    }
    return , $kutup.ToArray()
}

# ================================================================ 2) kurulu programlar ve AppData envanteri
function Get-KuruluIndeks {
    # normalleştirilmiş ad -> gösterilecek program adı. Sıralı: önce kayıt defteri, sonra klasörler, Store, oyunlar.
    # Böylece kısmi eşleşmede kayıt defterindeki gerçek program adı öncelik alır.
    $t = [ordered]@{}
    $ekle = { param($s, $goster) $n = Norm $s; if ($n.Length -ge 3 -and -not $t.Contains($n)) { $t[$n] = $(if ($goster) { $goster } else { $s }) } }
    $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    $adlar = @{}
    foreach ($k in Get-ItemProperty $keys -ErrorAction SilentlyContinue) {
        $dn = $k.PSObject.Properties['DisplayName']; if (-not ($dn -and $dn.Value)) { continue }
        $adlar[$dn.Value] = $true
        & $ekle $dn.Value $dn.Value
        $p = $k.PSObject.Properties['Publisher']; if ($p -and $p.Value) { & $ekle $p.Value "$($dn.Value) ($($p.Value))" }
        $p = $k.PSObject.Properties['InstallLocation']; if ($p -and $p.Value) { & $ekle (Split-Path $p.Value.TrimEnd('\') -Leaf) $dn.Value }
    }
    $script:Istatistik.Kayit = $adlar.Count
    foreach ($d in "$env:ProgramFiles", "${env:ProgramFiles(x86)}", "$L\Programs") {
        Get-ChildItem $d -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $ust = $_.Name
            & $ekle $ust "$ust (program klasörü)"
            Get-ChildItem $_.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object { & $ekle $_.Name "$ust\$($_.Name) (program klasörü)" }
        }
    }
    $appx = @(Get-AppxPackage -ErrorAction SilentlyContinue)
    $script:Istatistik.Store = @($appx | Where-Object { $_.SignatureKind -eq 'Store' }).Count
    foreach ($a in $appx) { & $ekle $a.Name "$($a.Name) (Store)"; $a.Name -split '\.' | ForEach-Object { & $ekle $_ "$($a.Name) (Store)" } }
    $steamOyun = 0
    foreach ($k in (Get-SteamKutuphaneleri)) {
        Get-ChildItem "$k\steamapps\common" -Directory -ErrorAction SilentlyContinue | ForEach-Object { $steamOyun++; & $ekle $_.Name "$($_.Name) (Steam)" }
    }
    $script:Istatistik.Steam = $steamOyun
    $epic = 0
    Get-ChildItem "$PD\Epic\EpicGamesLauncher\Data\Manifests\*.item" -ErrorAction SilentlyContinue | ForEach-Object {
        try { $n = (Get-Content $_.FullName -Raw | ConvertFrom-Json).DisplayName; $epic++; & $ekle $n "$n (Epic)" } catch {}
    }
    $script:Istatistik.Epic = $epic
    Get-Process -ErrorAction SilentlyContinue | ForEach-Object { & $ekle $_.ProcessName "$($_.ProcessName) (çalışıyor)" }
    return $t
}

# Klasör adını kurulu programlarla eşleştirir; eşleşen programın adını veya $null döndürür.
function Find-Eslesme([string]$ad, $idx) {
    $n = Norm $ad
    if ($n.Length -lt 3) { return '(ad çok kısa, değerlendirilmedi)' }
    if ($idx.Contains($n)) { return $idx[$n] }
    if ($n.Length -lt 4) { return $null }   # 3 harfli adlarda sadece birebir eşleşme (yanlış eşleşmeyi önler)
    foreach ($k in $idx.Keys) {
        if ($k.Contains($n) -or ($k.Length -ge 4 -and $n.Contains($k))) { return $idx[$k] }
    }
    return $null
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
# Sistem / ortak klasörlerin ne olduğu (raporda "Ait olduğu program" sütununda gösterilir)
$script:KlasorAciklamalari = @{
    'Microsoft' = 'Microsoft uygulamaları ve Windows bileşenleri'; 'Packages' = 'Microsoft Store uygulamalarının verileri'
    'Temp' = 'Geçici dosyalar'; 'Programs' = 'Kullanıcı için kurulan programlar (VS Code, Python, Cursor...)'
    'Publishers' = 'Windows uygulama yayıncı verileri'; 'ConnectedDevicesPlatform' = 'Windows bağlı cihazlar / Telefon Bağlantısı'
    'D3DSCache' = 'DirectX shader önbelleği'; 'VirtualStore' = 'Windows dosya sanallaştırma'
    'Package Cache' = 'Program kurulum paketleri önbelleği'; 'CrashDumps' = 'Programların çökme kayıtları'
    'SquirrelTemp' = 'Electron uygulama güncelleyicisi (Discord, Teams...)'; 'CEF' = 'Gömülü tarayıcı bileşeni (Chromium)'
    'Sentry' = 'Uygulama hata raporlama bileşeni'; 'DataSharing' = 'Windows veri paylaşımı'; 'OEM' = 'Bilgisayar üreticisinin verileri'
    'Intel' = 'Intel sürücü verileri'; 'NVIDIA' = 'NVIDIA sürücü önbellekleri'; 'NVIDIA Corporation' = 'NVIDIA uygulama verileri'
    'Google' = 'Google uygulamaları (Chrome, Android Studio...)'; 'Comms' = 'Windows Posta ve Takvim verileri'
    'Mozilla' = 'Firefox / Thunderbird'; 'Adobe' = 'Adobe ortak verileri'; 'Apple' = 'Apple yazılımları (iTunes, iCloud)'
    'Claude' = 'Claude uygulaması'; 'Claude-Data' = 'Claude uygulamasının verileri'; 'Claude-3p' = 'Claude uygulaması'
    'claude-cli-nodejs' = 'Claude Code'; 'npm-cache' = 'npm önbelleği (Node.js)'; 'pip' = 'pip önbelleği (Python)'
    'uv' = 'uv önbelleği (Python)'; 'Roaming\uv' = 'uv ayarları ve uv ile kurulan araçlar'
    'Roaming\Microsoft' = 'Microsoft uygulama ayarları ve Windows bileşenleri'; 'Roaming\Google' = 'Google uygulama ayarları'
    'Roaming\npm' = 'npm global paketleri (Node.js)'; '.dartServer' = 'Dart analiz önbelleği'; 'ms-playwright' = 'Playwright test tarayıcıları'
    'ms-playwright-go' = 'Playwright test tarayıcıları (Go)'; 'Android' = 'Android SDK (Android Studio)'; 'npm' = 'npm global paketleri (Node.js)'
    'BattlEye' = 'Oyun hile önleyicisi (birçok oyun ortak kullanır)'; 'EasyAntiCheat' = 'Oyun hile önleyicisi (birçok oyun ortak kullanır)'
    'EasyAntiCheat_EOS' = 'Oyun hile önleyicisi (birçok oyun ortak kullanır)'; 'History' = 'Windows geçmiş klasörü (eski)'
    'Application Data' = 'Windows uyumluluk bağlantısı'; 'Temporary Internet Files' = 'Internet Explorer önbelleği (eski)'
    'PlaceholderTileLogoFolder' = 'Başlat menüsü simgeleri'; 'ToastNotificationManagerCompat' = 'Windows bildirim bileşeni'
    'IsolatedStorage' = '.NET uygulama verileri'; 'Backup' = 'Windows uyumluluk yedeği'; 'DBG' = 'Windows hata ayıklama klasörü'
}

# Klasör adı programın adından farklı olanlar: klasör -> kurulu programda aranacak isim
$script:TakmaAdlar = @{
    'TS4' = 'thesims4'; 'LGLData' = 'logitech'; 'FMUAsistan' = 'thefmu'
    'EADesktop' = 'eaapp'; 'Link2EA' = 'eaapp'; 'EALaunchHelper' = 'eaapp'
}
# Klasör adı -> varlığını kontrol edeceğimiz komut (geliştirici araçları)
$script:AracKlasorleri = @{
    'Pub' = 'dart'; 'Dart' = 'dart'; '.dart-tool' = 'dart'; '.flutter-devtools' = 'flutter'; 'kotlin' = 'kotlin'
    'GitHub CLI' = 'gh'; 'firebase' = 'firebase'; 'Python' = 'python'; 'pip-audit' = 'pip-audit'
    'create-next-app-nodejs' = 'node'; 'nextjs-nodejs' = 'node'; 'ffmpeg-static-nodejs' = 'node'; 'main.kts.compiled.cache' = 'kotlin'
    'go-build' = 'go'; 'Yarn' = 'yarn'; 'pnpm' = 'pnpm'; 'pnpm-cache' = 'pnpm'
}

function Find-Artiklar {
    Write-Host '  Kurulu programlar okunuyor (kayıt defteri, Store, Steam, Epic)...' -ForegroundColor DarkGray
    $idx = Get-KuruluIndeks
    Write-Host '  AppData klasörleri tek tek ölçülüp programlarla eşleştiriliyor...' -ForegroundColor DarkGray
    foreach ($bolge in 'Local', 'LocalLow', 'Roaming') {
        Get-ChildItem "$U\AppData\$bolge" -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $ad = $_.Name
            if ($ad -like 'tw-*.tmp' -or $ad -like 'cbm-daemon-*') { return }
            if ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) { return }
            $durum = $null; $detay = $null; $artik = $false
            if ($script:SistemKlasorleri -contains $ad) {
                $durum = 'Sistem'
                $detay = if ($script:KlasorAciklamalari.ContainsKey("$bolge\$ad")) { $script:KlasorAciklamalari["$bolge\$ad"] }
                         elseif ($script:KlasorAciklamalari.ContainsKey($ad)) { $script:KlasorAciklamalari[$ad] }
                         else { 'Windows veya ortak bileşen' }
            } elseif ($script:AracKlasorleri.ContainsKey($ad)) {
                $komut = $script:AracKlasorleri[$ad]
                if (Get-Command $komut -ErrorAction SilentlyContinue) { $durum = 'Araç'; $detay = "$komut komutu kurulu" }
                else { $durum = 'ARTIK'; $detay = "İlgili araç ($komut) bulunamadı"; $artik = $true }
            } else {
                $es = Find-Eslesme $ad $idx
                if (-not $es -and $script:TakmaAdlar.ContainsKey($ad)) { $es = Find-Eslesme $script:TakmaAdlar[$ad] $idx }
                if (-not $es) {
                    # Şirket\Oyun yapısı (özellikle LocalLow): alt klasörlerden biri kurulu bir programsa artık değildir
                    foreach ($alt in Get-ChildItem -LiteralPath $_.FullName -Directory -Force -ErrorAction SilentlyContinue) {
                        # Alt klasörde sadece birebir eşleşme: "Cache", "mcp_resources" gibi genel adlar kısmi eşleşmede yanlış sonuç verir
                        $an = Norm $alt.Name
                        if ($an.Length -lt 5 -or -not $idx.Contains($an)) { continue }
                        $es = "$($idx[$an]) (alt klasör: $($alt.Name))"; break
                    }
                }
                if ($es) { $durum = 'Kurulu'; $detay = $es }
                else { $durum = 'ARTIK'; $detay = 'Kurulu bir programla eşleşmedi'; $artik = $true }
            }
            $bayt = Get-Boyut @($_.FullName)
            $etiket = if ($artik) { 'KONTROL ET' } else { 'DOKUNMA' }
            $script:Envanter.Add([pscustomobject]@{ Bolge = $bolge; Ad = $ad; Bayt = $bayt; Durum = $durum; Etiket = $etiket; Detay = $detay; Yol = $_.FullName })
            if ($artik) {
                Add-Aday "$bolge\$ad" @($_.FullName) 'KONTROL' 'Artık' "$detay. İçinde oyun kaydı veya ayar olabilir"
            }
        }
    }
}

# ================================================================ 3) taranan ama silme listesine alınmayanlar (DOKUNMA)
function Find-Bilgiler {
    Write-Host '  Büyük programlar, oyunlar ve sistem dosyaları...' -ForegroundColor DarkGray
    # Not: Bu bölüm öneri vermez. Her öğe için sadece ne olduğu ve silinirse ne olacağı yazılır.

    # Korumalı yollar (silme listesine hiçbir zaman girmez)
    $korumaliAciklama = [ordered]@{
        "$L\Microsoft\WinGet"                              = 'winget ile kurulan programların kendisi. Silinirse bu programlar çalışmaz'
        "$env:windir\Installer"                            = 'Programların kaldırma/güncelleme dosyaları. Silinirse programlar kaldırılamaz ve güncellenemez'
        "$env:ProgramFiles\NVIDIA Corporation\Installer2"  = 'NVIDIA bileşenlerinin kaldırma/onarma dosyaları'
        "$PD\LGHUB\depots"                                 = 'Logitech G HUB''ın çalışan paketi'
        "$R\uv"                                            = 'uv ayarları ve uv ile kurulan araçlar'
        "$U\.cache\codex-runtimes"                         = 'Codex çalışma ortamı'
        "$L\Claude-Data"                                   = 'Claude uygulamasının verileri'
    }
    foreach ($y in $korumaliAciklama.Keys) {
        if (Test-Path -LiteralPath $y) { Add-Bilgi $y (Get-Boyut @($y)) $korumaliAciklama[$y] }
    }
    # Kurulu oyunlar (sistem sürücüsündeki büyük Steam oyunları)
    foreach ($k in (Get-SteamKutuphaneleri | Where-Object { $_.StartsWith($SD, [StringComparison]::OrdinalIgnoreCase) })) {
        Get-ChildItem "$k\steamapps\common" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $b = Get-Boyut @($_.FullName)
            if ($b -ge 5GB) { Add-Bilgi "Steam oyunu: $($_.Name) ($SD sürücüsünde)" $b 'Kurulu oyun dosyaları. Elle silinirse oyun çalışmaz' }
        }
    }
    # Store uygulamalarının verileri
    $paketAd = @{}
    Get-AppxPackage -ErrorAction SilentlyContinue | ForEach-Object { $paketAd[$_.PackageFamilyName] = $_.Name }
    Get-ChildItem "$L\Packages" -Directory -ErrorAction SilentlyContinue | Where-Object { -not (Test-Korumali $_.FullName) } | ForEach-Object {
        $b = Get-Boyut @($_.FullName)
        if ($b -ge 500MB) {
            $ad = if ($paketAd.ContainsKey($_.Name)) { $paketAd[$_.Name] } else { $_.Name }
            Add-Bilgi "Store uygulaması verisi: $ad" $b 'Kurulu Store uygulamasının verisi. Elle silinirse uygulama bozulabilir'
        }
    }
    # Sistem dosyaları
    $hib = Get-ChildItem "$SD\" -Force -File -Filter 'hiberfil.sys' -ErrorAction SilentlyContinue
    if ($hib) { Add-Bilgi 'hiberfil.sys (hazırda bekletme)' $hib.Length 'Windows sistem dosyası. Windows yönetir' }
    $pg = Get-ChildItem "$SD\" -Force -File -Filter 'pagefile.sys' -ErrorAction SilentlyContinue
    if ($pg) { Add-Bilgi 'pagefile.sys (sanal bellek)' $pg.Length 'Windows sistem dosyası. Windows yönetir' }
    # Yönetici yetkisi gerektirenler
    if (Test-Yonetici) {
        $vss = (vssadmin list shadowstorage 2>$null) -join "`n"
        if ($vss -match 'Used Shadow Copy Storage space:\s*([\d,\.]+)\s*(GB|MB)') {
            $sayi = [double]($Matches[1] -replace ',', '.'); $b = if ($Matches[2] -eq 'GB') { [long]($sayi * 1GB) } else { [long]($sayi * 1MB) }
            Add-Bilgi 'Sistem geri yükleme noktaları' $b 'Windows''un sistem koruması. Windows yönetir'
        }
        Add-Bilgi "$env:ProgramFiles\WindowsApps" (Get-Boyut @("$env:ProgramFiles\WindowsApps")) 'Store uygulamalarının programları. Elle silinirse uygulamalar ve Microsoft Store bozulur'
    } else {
        Add-Bilgi 'Geri yükleme noktaları ve WindowsApps' 0 'Ölçülemedi: yönetici yetkisi gerekiyor'
    }
}

# ================================================================ ekrana yazdırma
function Write-Baslik([string]$metin) {
    Write-Host ''
    Write-Host ('=' * 90) -ForegroundColor DarkCyan
    Write-Host " $metin" -ForegroundColor Cyan
    Write-Host ('=' * 90) -ForegroundColor DarkCyan
}

function Get-EtiketRengi([string]$e) {
    switch ($e) { 'GÜVENLİ' { 'Green' } 'KONTROL ET' { 'Yellow' } 'DOKUNMA' { 'Red' } default { 'Gray' } }
}

function Show-Envanter {
    $tum = @($script:Envanter | Sort-Object Bayt -Descending)
    Write-Baslik ("TARANAN UYGULAMA KLASÖRLERİ: {0} AppData klasörü, toplam {1}" -f $tum.Count, (Format-Boyut ([long](($tum | Measure-Object Bayt -Sum).Sum))))
    Write-Host ("Karşılaştırılan kurulu programlar: {0} kayıt defteri girdisi, {1} Store uygulaması, {2} Steam oyunu, {3} Epic oyunu" -f `
        $script:Istatistik.Kayit, $script:Istatistik.Store, $script:Istatistik.Steam, $script:Istatistik.Epic) -ForegroundColor DarkGray
    foreach ($d in @(@('Kurulu', 'kurulu bir programa ait'), @('Sistem', 'Windows, ortak bileşen veya bilinen klasör'), @('Araç', 'kurulu bir geliştirici aracına ait'), @('ARTIK', 'kurulu bir programla eşleşmedi'))) {
        $g = @($tum | Where-Object Durum -eq $d[0])
        if ($g.Count) { Write-Host ("  {0,3} klasör ({1,8}): {2}" -f $g.Count, (Format-Boyut ([long](($g | Measure-Object Bayt -Sum).Sum))), $d[1]) -ForegroundColor DarkGray }
    }
    Write-Host '  Etiket klasörün tamamı içindir. İçindeki önbellekler ayrıca TEMİZLENEBİLECEKLER listesinde olabilir.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host ('{0,9}  {1,-10} {2,-34} {3}' -f 'Boyut', 'Etiket', 'Klasör', 'Ait olduğu program') -ForegroundColor White
    Write-Host ('-' * 100)
    foreach ($e in $tum) {
        $klasor = "$($e.Bolge)\$($e.Ad)"; if ($klasor.Length -gt 34) { $klasor = $klasor.Substring(0, 31) + '...' }
        $detay = "$($e.Detay)"; if ($detay.Length -gt 50) { $detay = $detay.Substring(0, 47) + '...' }
        Write-Host ('{0,9}  ' -f (Format-Boyut $e.Bayt)) -NoNewline
        Write-Host ('{0,-10}' -f $e.Etiket) -ForegroundColor (Get-EtiketRengi $e.Etiket) -NoNewline
        Write-Host (' {0,-34} {1}' -f $klasor, $detay)
    }
}

function Show-Bilgiler {
    if ($script:Bilgiler.Count -eq 0) { return }
    Write-Baslik 'TARANAN AMA SİLME LİSTESİNE ALINMAYANLAR'
    foreach ($b in ($script:Bilgiler | Sort-Object Bayt -Descending)) {
        $boyut = if ($b.Bayt -gt 0) { Format-Boyut $b.Bayt } else { '?' }
        Write-Host ('{0,9}  ' -f $boyut) -NoNewline
        Write-Host ('{0,-10}' -f $b.Etiket) -ForegroundColor (Get-EtiketRengi $b.Etiket) -NoNewline
        Write-Host (' {0}' -f $b.Ad)
        Write-Host ('                       {0}' -f $b.Aciklama) -ForegroundColor DarkGray
    }
}

function Show-Liste($liste) {
    Write-Baslik 'TEMİZLENEBİLECEKLER'
    Write-Host ('{0,3}  {1,-10} {2,9}  {3}' -f 'No', 'Etiket', 'Boyut', 'Ad / Açıklama') -ForegroundColor White
    Write-Host ('-' * 100)
    for ($i = 0; $i -lt $liste.Count; $i++) {
        $a = $liste[$i]
        $etiket = if ($a.Risk -eq 'GUVENLI') { 'GÜVENLİ' } else { 'KONTROL ET' }
        Write-Host ('{0,3}  ' -f ($i + 1)) -NoNewline
        Write-Host ('{0,-10}' -f $etiket) -ForegroundColor (Get-EtiketRengi $etiket) -NoNewline
        Write-Host (' {0,9}  {1}' -f (Format-Boyut $a.Bayt), $a.Ad)
        Write-Host ('                          {0}' -f $a.Not) -ForegroundColor DarkGray
    }
    $g = ($liste | Where-Object Risk -eq 'GUVENLI' | Measure-Object Bayt -Sum).Sum
    $k = ($liste | Where-Object Risk -eq 'KONTROL' | Measure-Object Bayt -Sum).Sum
    Write-Host ('-' * 100)
    Write-Host ("GÜVENLİ toplam: {0}    KONTROL ET toplam: {1}" -f (Format-Boyut ([long]$g)), (Format-Boyut ([long]$k)))
}

# ================================================================ seçim ve silme
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
    foreach ($y in $a.Yollar) { [void]$script:BoyutHafiza.Remove($y) }
    # Doğrulama
    if ($a.Komut) { return ((Get-Boyut $a.Yollar -Taze) -lt [math]::Max(1MB, $a.Bayt * 0.05)) }
    return (@($a.Yollar | Where-Object { Test-Path -LiteralPath $_ }).Count -eq 0)
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
    Write-Host 'Bu program öneri vermez. Etiketler (GÜVENLİ / KONTROL ET / DOKUNMA) yalnızca dosyanın türünü gösterir;' -ForegroundColor DarkGray
    Write-Host 'silme kararı ve sorumluluğu kullanıcıya aittir.' -ForegroundColor DarkGray
    if (-not (Test-Yonetici)) { Write-Host 'Yönetici olarak çalıştırılmadı: geri yükleme noktaları ve WindowsApps ölçülmeyecek.' -ForegroundColor DarkGray }
    Write-Host 'Taranıyor (bilgisayarına göre 3-6 dakika sürebilir)...'
    $script:Adaylar.Clear(); $script:Envanter.Clear(); $script:Bilgiler.Clear()
    Find-Artiklar
    Find-Onbellekler
    Find-Bilgiler
    if ($Csv) {
        $script:Adaylar | Sort-Object Bayt -Descending |
            Select-Object Ad, Risk, Kategori, @{n = 'MB'; e = { [math]::Round($_.Bayt / 1MB, 1) } }, Not, @{n = 'Yollar'; e = { $_.Yollar -join ' | ' } } |
            Export-Csv $Csv -NoTypeInformation -Encoding UTF8
        $envCsv = [IO.Path]::ChangeExtension($Csv, $null).TrimEnd('.') + '-envanter.csv'
        $envanterSatirlari = @($script:Envanter | ForEach-Object {
                [pscustomobject]@{ Bolum = 'AppData'; Ad = "$($_.Bolge)\$($_.Ad)"; Etiket = $_.Etiket; Aciklama = $_.Detay; MB = [math]::Round($_.Bayt / 1MB, 1); Yol = $_.Yol } }) +
            @($script:Bilgiler | ForEach-Object {
                [pscustomobject]@{ Bolum = 'Silme listesi dışı'; Ad = $_.Ad; Etiket = $_.Etiket; Aciklama = $_.Aciklama; MB = [math]::Round($_.Bayt / 1MB, 1); Yol = '' } })
        $envanterSatirlari | Sort-Object MB -Descending | Export-Csv $envCsv -NoTypeInformation -Encoding UTF8
        Write-Host "Rapor kaydedildi: $Csv ve $envCsv"
    }
    Show-Envanter
    Show-Bilgiler
    if ($script:Adaylar.Count -eq 0) { Write-Host ''; Write-Host 'Temizlenecek bir şey bulunamadı.' -ForegroundColor Green; return }
    if ($SadeceRapor) { Show-Liste @($script:Adaylar | Sort-Object Bayt -Descending); return }
    Invoke-Menu
}

if (-not $NoRun) { Start-Temizleyici }
