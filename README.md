# 🧹 Disk Temizleyici

**Windows için onaylı, şeffaf disk tarama ve temizleme aracı.**
Bilgisayarındaki uygulama klasörlerini, önbellekleri, eski sürüm dosyalarını ve kaldırılmış programlardan kalan klasörleri tarar. Taradığı **her şeyi** boyutuyla birlikte listeler ve yanına tarafsız bir etiket koyar. **Hiçbir şeyi sen onaylamadan silmez.**

![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D6)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE)
![Bağımlılık](https://img.shields.io/badge/bağımlılık-yok-brightgreen)
![Lisans](https://img.shields.io/badge/lisans-MIT-blue)

> ⚖️ **Bu program öneri vermez.** Etiketler yalnızca bir dosyanın türünü ve silinirse ne olacağını gösterir. Neyin silineceğine dair karar ve sorumluluk tamamen kullanıcıya aittir. Ayrıntılar için [Sorumluluk reddi](#sorumluluk-reddi) bölümüne bak.

---

## İçindekiler

- [Neden bu araç?](#neden-bu-araç)
- [Temel ilkeler](#temel-ilkeler)
- [Etiketler](#etiketler)
- [Özellikler](#özellikler)
- [Gereksinimler](#gereksinimler)
- [Kurulum](#kurulum)
- [Kullanım](#kullanım)
  - [Çift tıklayarak](#1-çift-tıklayarak)
  - [PowerShell'den](#2-powershellden)
  - [Parametreler](#parametreler)
  - [Raporun üç bölümü](#raporun-üç-bölümü)
  - [Menü adım adım](#menü-adım-adım)
  - [Örnek çıktı](#örnek-çıktı)
- [Neleri tarar?](#neleri-tarar)
- [Asla silme listesine girmeyenler (DOKUNMA)](#asla-silme-listesine-girmeyenler-dokunma)
- [Artık klasör tespiti nasıl çalışır?](#artık-klasör-tespiti-nasıl-çalışır)
- [Silme yöntemleri](#silme-yöntemleri)
- [CSV raporu](#csv-raporu)
- [Testler](#testler)
- [Özelleştirme](#özelleştirme)
- [Sık sorulan sorular ve sorun giderme](#sık-sorulan-sorular-ve-sorun-giderme)
- [Bilinen sınırlamalar](#bilinen-sınırlamalar)
- [Proje yapısı](#proje-yapısı)
- [Katkıda bulunma](#katkıda-bulunma)
- [Sorumluluk reddi](#sorumluluk-reddi)
- [Lisans](#lisans)

---

## Neden bu araç?

Windows'ta zamanla gigabaytlarca dosya birikir ve bunların çoğu Windows'un kendi **Disk Temizleme** aracının hiç bakmadığı yerlerdedir:

- Geliştirici araçlarının önbellekleri (`uv`, `npm`, `pip`, `Yarn`, `Go`, `NuGet`, `Gradle`, Dart, Playwright)
- Tarayıcı ve Electron uygulamalarının önbellekleri (Chrome, Edge, Opera, Discord, VS Code, Cursor...)
- Editörlerin sakladığı **eski eklenti sürümleri**
- NVIDIA App'in indirip kurduktan sonra silmediği **sürücü paketleri** (her biri ~4 GB)
- Hiçbir emülatörün kullanmadığı **Android sistem imajları** (her biri 2-3 GB)
- Android Studio'nun **eski sürümlerinden** kalan ayar klasörleri
- Kaldırdığın oyun ve programların `AppData` içinde bıraktığı **artık klasörler**
- `Downloads` klasöründeki büyük **kurulum dosyaları ve arşivler**

Bu araç bunları bir arada bulur. Ama "temizleyici" programların en büyük riski yanlış şeyi silmeleridir. Bu yüzden araç **karar vermez ve öneri yapmaz**. Neyi bulduğunu, ne olduğunu ve silinirse ne olacağını gösterir; gerisini sana bırakır.

## Temel ilkeler

1. **Onaysız silme yok.** Her silme işleminden önce silinecek her yol ekranda gösterilir ve devam etmek için `EVET` yazman gerekir.
2. **Şeffaflık.** Taranan her uygulama klasörü, silinebilir olsun olmasın, boyutuyla ve hangi programa ait olduğuyla listelenir.
3. **Öneri yok, sadece etiket.** Program "şunu sil" demez. Her öğenin yanında dosyanın türünü anlatan tarafsız bir etiket bulunur.
4. **Emin olunmayan her şey "KONTROL ET" olarak işaretlenir.** Kendini yeniden oluşturmayan, içinde kayıt veya ayar olabilecek hiçbir şey "GÜVENLİ" sayılmaz.
5. **Kritik yollar koda gömülü bir korumayla engellenir.** Bu yollar "DOKUNMA" etiketiyle gösterilir ama silme listesine hiçbir koşulda giremez; silme anında da bir kez daha kontrol edilir.
6. **Silme sonrası doğrulama.** Her öğe silindikten sonra gerçekten gidip gitmediği kontrol edilir ve kilitli dosya kalırsa bildirilir.
7. **Araçların kendi temizleme komutu kullanılır.** `uv`, `npm`, `pip`, `yarn`, `go` ve `dotnet` önbellekleri doğrudan silinmez, aracın kendi komutuyla temizlenir.

## Etiketler

| Etiket | Ne anlama gelir? | Silme listesinde mi? | Örnekler |
|---|---|---|---|
| 🟢 **GÜVENLİ** | Dosyalar gerektiğinde kendiliğinden yeniden oluşur veya zaten kullanılmış dosyalardır. Silinmeleri bir programı bozmaz; en fazla bir sonraki kullanımda bekleme olur | ✅ Evet | Önbellekler, kurulu sürücünün kurulum dosyası, çökme kayıtları, kullanılmayan Android imajları |
| 🟡 **KONTROL ET** | Araç ne olduğundan %100 emin değil. İçinde oyun kaydı, ayar veya yeniden indirilmesi zor bir dosya olabilir. Ne olduğuna kullanıcının bakması gerekir | ✅ Evet | Kurulu programla eşleşmeyen klasörler, emülatörler, Downloads'taki dosyalar, projede kullanılan Gradle sürümü |
| 🔴 **DOKUNMA** | Silinirse bir program, oyun veya Windows bozulabilir | ❌ **Hayır**, sadece bilgi olarak gösterilir | winget programları, Windows Installer, kurulu oyunlar, Store uygulamaları, kurulu programların AppData klasörleri, sistem dosyaları |

`g` kısayolu yalnızca GÜVENLİ öğeleri seçer. KONTROL ET öğeleri ancak numarası elle yazılırsa seçilir. DOKUNMA öğelerinin numarası yoktur, seçilemezler.

## Özellikler

- 🔍 **Kapsamlı tarama:** 20'den fazla önbellek ve eski sürüm kuralı, tüm AppData klasörleri, büyük oyunlar ve Store uygulamaları
- 📋 **Tam envanter:** Taranan her AppData klasörü boyutu, etiketi ve ait olduğu programla birlikte listelenir
- 🏷️ **Üç tarafsız etiket:** GÜVENLİ / KONTROL ET / DOKUNMA
- 📊 **Boyuta göre sıralama:** En çok yer kaplayan öğe en üstte
- 🎯 **Esnek seçim:** `1,3,5-7` gibi numaralar veya tek tuşla tüm GÜVENLİ öğeler
- ♻️ **İki silme yöntemi:** Geri Dönüşüm Kutusu (geri alınabilir) veya kalıcı silme
- 🛡️ **Koda gömülü koruma:** winget programları, Windows Installer önbelleği, WindowsApps ve benzerleri asla silinmez
- ⚡ **Hızlı ölçüm:** Klasör boyutları .NET ile ölçülür; PowerShell'in `Get-ChildItem` komutundan 2-3 kat hızlı ve aynı sonucu verir
- 📏 **Açılan yer raporu:** Her turdan sonra C: sürücüsünde ne kadar yer açıldığı gösterilir
- 📄 **CSV rapor:** Bütün tarama sonuçları Excel'de açılabilecek iki dosyaya kaydedilebilir
- 🧪 **Testli:** Seçim, onay, koruma, eşleştirme ve sürüm karşılaştırma mantığı 33 otomatik testle doğrulanır
- 📦 **Bağımlılık yok:** Windows'ta yerleşik gelen PowerShell 5.1 ile çalışır, kurulum gerektirmez

## Gereksinimler

| Gereksinim | Not |
|---|---|
| Windows 10 veya 11 | Windows 11 üzerinde geliştirildi ve test edildi |
| PowerShell 5.1 veya üstü | Windows ile birlikte gelir, ek kurulum gerekmez |
| Yönetici yetkisi | **Gerekmez.** Yönetici olarak çalıştırılırsa geri yükleme noktaları ve `WindowsApps` da ölçülür. `C:\ProgramData` altındaki bazı dosyaları (örn. NVIDIA paketleri) silmek için gerekebilir |

## Kurulum

**Git ile:**

```bash
git clone https://github.com/GeneralBuSa/disk-temizleyici.git
cd disk-temizleyici
```

**Git olmadan (tarayıcıdan):** GitHub sayfasında yeşil **Code** butonu → **Download ZIP**. ZIP'e sağ tık → **Tümünü ayıkla**.

**Git olmadan (PowerShell'den):**

```powershell
Invoke-WebRequest https://github.com/GeneralBuSa/disk-temizleyici/archive/refs/heads/main.zip -OutFile disk-temizleyici.zip
Expand-Archive disk-temizleyici.zip -DestinationPath .
cd disk-temizleyici-main
```

> ⚠️ İnternetten indirilen dosyaları Windows "engellenmiş" olarak işaretleyebilir. Klasörde PowerShell açıp şunu çalıştırarak engeli kaldırabilirsin:
>
> ```powershell
> Get-ChildItem | Unblock-File
> ```

## Kullanım

### 1. Çift tıklayarak

`DiskTemizleyici.bat` dosyasına çift tıkla. PowerShell'in betik çalıştırma kısıtlamasını yalnızca bu çalıştırma için aşar, sistem ayarlarını değiştirmez. Geri yükleme noktalarının ve Store uygulamalarının da ölçülmesi için sağ tık → **Yönetici olarak çalıştır**.

### 2. PowerShell'den

Klasörde boş bir yere **Shift + sağ tık → PowerShell penceresini burada aç** de ve şunu çalıştır:

```powershell
powershell -ExecutionPolicy Bypass -File .\DiskTemizleyici.ps1
```

### Parametreler

| Parametre | Açıklama | Örnek |
|---|---|---|
| *(parametresiz)* | Tara, raporla, seçim menüsünü aç | `.\DiskTemizleyici.ps1` |
| `-SadeceRapor` | Sadece tara ve raporla. Silme menüsü hiç açılmaz | `.\DiskTemizleyici.ps1 -SadeceRapor` |
| `-Csv <dosya>` | Raporu ayrıca CSV olarak kaydet (bkz. [CSV raporu](#csv-raporu)) | `.\DiskTemizleyici.ps1 -Csv rapor.csv` |
| `-NoRun` | Sadece fonksiyonları yükler, hiçbir şey çalıştırmaz (testler için) | `. .\DiskTemizleyici.ps1 -NoRun` |

Parametreler birlikte kullanılabilir ve `.bat` dosyası da parametreleri aktarır:

```powershell
.\DiskTemizleyici.ps1 -SadeceRapor -Csv "$env:USERPROFILE\Desktop\disk-raporu.csv"
```

```bat
DiskTemizleyici.bat -SadeceRapor
```

### Raporun üç bölümü

Tarama bitince ekrana sırasıyla üç bölüm yazılır:

| # | Bölüm | İçerik | Seçilebilir mi? |
|---|---|---|---|
| 1 | **TARANAN UYGULAMA KLASÖRLERİ** | `AppData\Local`, `LocalLow` ve `Roaming` altındaki **her klasör**: boyutu, etiketi ve ait olduğu program. Başında kaç kurulu programla karşılaştırıldığı ve klasörlerin kurulu / sistem / araç / eşleşmeyen dağılımı yazar | ❌ Sadece bilgi |
| 2 | **TARANAN AMA SİLME LİSTESİNE ALINMAYANLAR** | Korumalı yollar, sistem sürücüsündeki büyük oyunlar, Store uygulamalarının verileri, sistem dosyaları (`hiberfil.sys`, `pagefile.sys`), yönetici olarak çalıştırıldıysa geri yükleme noktaları ve `WindowsApps`. Hepsi **DOKUNMA** etiketlidir | ❌ Sadece bilgi |
| 3 | **TEMİZLENEBİLECEKLER** | GÜVENLİ ve KONTROL ET etiketli, numaralı öğeler | ✅ Evet |

> 1. bölümdeki etiket **klasörün tamamı** içindir. Örneğin `Roaming\discord` kurulu bir programa ait olduğu için DOKUNMA etiketlidir, ama içindeki önbellek klasörleri 3. bölümde ayrıca "Önbellek: discord" olarak GÜVENLİ etiketiyle görünebilir.

### Menü adım adım

**1. Tarama.** Program açılınca tarama başlar. Bütün klasörlerin boyutu ölçüldüğü için bilgisayarına göre **3-6 dakika** sürebilir. Pencereyi kapatma.

**2. Rapor.** Yukarıdaki üç bölüm ekrana yazılır.

**3. Seçim.** 3. bölümdeki numaralardan seçim yap:

| Girdi | Anlamı |
|---|---|
| `3` | Sadece 3 numara |
| `1,4,7` | 1, 4 ve 7 numara |
| `2-5` | 2'den 5'e kadar hepsi |
| `1,3,6-9` | Karışık kullanım |
| `g` | Tüm **GÜVENLİ** öğeler (KONTROL ET olanlar dahil edilmez) |
| `q` veya boş Enter | Çıkış |

Geçersiz bir girdi (olmayan bir numara, harf, ters aralık) hiçbir şey seçmez ve menü tekrar gösterilir.

**4. Özet.** Seçilen her öğe, silinecek yollarıyla birlikte listelenir ve toplam boyut gösterilir.

**5. Yöntem.** `1` Geri Dönüşüm Kutusu veya `2` Kalıcı silme. Başka bir şey yazılırsa işlem iptal edilir.

**6. Onay.** `EVET` yaz (büyük-küçük harf fark etmez). **Başka herhangi bir cevap işlemi iptal eder ve hiçbir şey silinmez.**

**7. Sonuç.** Her öğe için `TAMAM` veya `KISMEN` yazılır ve açılan toplam yer gösterilir. Silinen öğeler listeden çıkar, menü kalan öğelerle tekrar açılır.

### Örnek çıktı

```text
==========================================================================================
 TARANAN UYGULAMA KLASÖRLERİ: 113 AppData klasörü, toplam 60,3 GB
==========================================================================================
Karşılaştırılan kurulu programlar: 135 kayıt defteri girdisi, 118 Store uygulaması, 7 Steam oyunu, 0 Epic oyunu
   44 klasör (  9,2 GB): kurulu bir programa ait
   45 klasör ( 50,1 GB): Windows, ortak bileşen veya bilinen klasör
   10 klasör (  826 MB): kurulu bir geliştirici aracına ait
   14 klasör (  213 MB): kurulu bir programla eşleşmedi

    Boyut  Etiket      Klasör                             Ait olduğu program
----------------------------------------------------------------------------------------------------
  21,1 GB  DOKUNMA     Local\Packages                     Microsoft Store uygulamalarının verileri
   6,3 GB  DOKUNMA     Local\Programs                     Kullanıcı için kurulan programlar (VS Code, Pyt...
   ...
           DOKUNMA     LocalLow\Curve Animation           Liar's Bar (Steam) (alt klasör: Liar's Bar)
           DOKUNMA     Roaming\uv                         uv ayarları ve uv ile kurulan araçlar
           KONTROL ET  Local\UnrealEngine                 Kurulu bir programla eşleşmedi
           KONTROL ET  Local\kotlin                       İlgili araç (kotlin) bulunamadı

==========================================================================================
 TARANAN AMA SİLME LİSTESİNE ALINMAYANLAR
==========================================================================================
  68,9 GB  DOKUNMA     Steam oyunu: Counter-Strike Global Offensive (C: sürücüsünde)
                         Kurulu oyun dosyaları. Elle silinirse oyun çalışmaz
  11,5 GB  DOKUNMA     pagefile.sys (sanal bellek)
                         Windows sistem dosyası. Windows yönetir
   ...

==========================================================================================
 TEMİZLENEBİLECEKLER
==========================================================================================
  ...  GÜVENLİ     uv önbelleği          Kendini yeniden oluşturur
  ...  KONTROL ET  Downloads\*.exe       Kurulum dosyası; tekrar indirmek gerekebilir
```

---

## Neleri tarar?

### Geliştirici araçlarının önbellekleri

| Öğe | Konum | Etiket | Nasıl temizlenir |
|---|---|---|---|
| **uv** | `uv cache dir` komutunun gösterdiği yer | GÜVENLİ | `uv cache clean` |
| **npm** | `%LOCALAPPDATA%\npm-cache\_cacache` | GÜVENLİ | `npm cache clean --force` |
| **pip** | `%LOCALAPPDATA%\pip\cache` | GÜVENLİ | `python -m pip cache purge` |
| **Yarn** | `%LOCALAPPDATA%\Yarn\Cache` | GÜVENLİ | `yarn cache clean` |
| **Go** | `go env GOCACHE` | GÜVENLİ | `go clean -cache` |
| **NuGet** | `~\.nuget\packages` | KONTROL ET | `dotnet nuget locals all --clear` |
| **Dart analiz önbelleği** | `%LOCALAPPDATA%\.dartServer` | GÜVENLİ | Klasör silinir |
| **Playwright tarayıcıları** | `%LOCALAPPDATA%\ms-playwright`, `ms-playwright-go` | GÜVENLİ | Klasör silinir |

> Komutla temizlenen önbellekler yalnızca ilgili araç kuruluysa listelenir ve 1 MB'tan küçükse (yani zaten temizse) gösterilmez.

### Tarayıcı ve uygulama önbellekleri

| Öğe | Nasıl bulunur | Etiket |
|---|---|---|
| **Tarayıcılar** | Chrome, Edge, Brave, Opera, Opera GX, Vivaldi: her profilin `Cache`, `Code Cache`, `GPUCache` klasörleri ve kök dizindeki shader önbellekleri | GÜVENLİ |
| **Firefox** | Her profilin `cache2` klasörü | GÜVENLİ |
| **Electron uygulamaları** | `Roaming` ve `Local` altında `Code Cache` veya `GPUCache` içeren her uygulama (Discord, VS Code, Cursor, Teams, Slack...): `Cache`, `Code Cache`, `GPUCache`, `CachedData`, `Crashpad`, `Dawn*Cache`, `CachedExtensionVSIXs` | GÜVENLİ |

20 MB'tan küçük uygulama önbellekleri listelenmez. Program açıkken bazı dosyalar kilitli olabilir; bu durumda sonuç `KISMEN` olur.

### Geçici dosyalar

| Öğe | Konum | Etiket |
|---|---|---|
| **Çökme kayıtları** | `%LOCALAPPDATA%\CrashDumps\*` | GÜVENLİ |
| **Eski geçici dosyalar** | `%TEMP%` içinde 7 günden eski dosya ve klasörler | GÜVENLİ |
| **`tw-*.tmp` klasörleri** | `%LOCALAPPDATA%\tw-*.tmp` | GÜVENLİ |

### Eski sürümler, emülatörler ve kurulum dosyaları

| Öğe | Nasıl karar verir | Etiket |
|---|---|---|
| **Editör eklentilerinin eski sürümleri** (`.vscode`, `.cursor`, `.windsurf`, `.antigravity*`, `.kiro`, `.trae`) | Aynı eklentinin (aynı platform için) birden fazla sürümü varsa, en yenisi dışındakiler. Sürümler sayısal karşılaştırılır (`2025.12.1` < `2026.2.0`) | GÜVENLİ |
| **Gradle sürümleri** (`~\.gradle\caches\<sürüm>` ve `wrapper\dists`) | Projelerdeki `gradle-wrapper.properties` dosyaları taranır. Hiçbir projenin kullanmadığı sürüm GÜVENLİ, kullanılan sürüm KONTROL ET | GÜVENLİ / KONTROL ET |
| **Eski Android Studio verisi** (`AndroidStudio20xx.x.x`) | `Local\Google` ve `Roaming\Google` altında en yeni sürüm dışındakiler | GÜVENLİ |
| **Android sistem imajları** (`Sdk\system-images\...`) | Her emülatörün `config.ini` dosyasındaki `image.sysdir` satırı okunur. Hiçbir emülatörün kullanmadığı imajlar listelenir. Derleme için gerekmezler | GÜVENLİ |
| **Android emülatör programı** (`Sdk\emulator`) | Yalnızca hiç emülatör yoksa | GÜVENLİ |
| **Android emülatörleri** (`~\.android\avd\*.avd`) | Her emülatör ayrı listelenir | KONTROL ET |
| **Eski Android NDK sürümleri** | Birden fazla NDK varsa en yenisi dışındakiler. Bir proje eski sürümü sabitlemiş olabilir | KONTROL ET |
| **NVIDIA sürücü paketleri** (`NVIDIA App\UpdateFramework\ota-artifacts\grd`) | Paketteki `.exe` adından sürüm okunur ve kurulu sürücüyle karşılaştırılır. Kurulu sürüm GÜVENLİ, kurulmamış güncelleme KONTROL ET | GÜVENLİ / KONTROL ET |
| **NVIDIA shader önbelleği** (`DXCache`, `GLCache`) | Oyunlar ilk açılışta takılır ve önbellek kısa sürede geri dolar | KONTROL ET |
| **Steam shader önbelleği** (tüm kütüphaneler) | Oyunlar ilk açılışta shader derler | KONTROL ET |
| **Logitech G HUB güncelleme önbelleği** | G HUB'ın indirdiği güncelleme kopyası | KONTROL ET |
| **Downloads'taki büyük dosyalar** | `.exe .msi .zip .rar .7z .iso`, 50 MB'tan büyük ve 30 günden eski. Arşivin çıkarılmış hali yanındaysa bu da yazılır | KONTROL ET |

Gradle projeleri şu klasörlerde aranır (6 seviye derinliğe kadar): `StudioProjects`, `Developer`, `Documents`, `Downloads`, `Desktop`, `source`, `Projects`.

### Uygulama klasörleri (AppData envanteri)

`AppData\Local`, `AppData\LocalLow` ve `AppData\Roaming` altındaki **her klasör** ölçülür ve kurulu programlarla karşılaştırılır. Her biri raporun 1. bölümünde şu durumlardan biriyle listelenir:

| Durum | Etiket | Anlamı |
|---|---|---|
| Kurulu | DOKUNMA | Kurulu bir programa ait. Yanında programın adı yazar (örn. `Discord`, `The Sims 4 (Steam)`) |
| Sistem | DOKUNMA | Windows'a veya birçok programın ortak kullandığı bir bileşene ait |
| Araç | DOKUNMA | Kurulu bir geliştirici aracına ait (örn. `dart komutu kurulu`) |
| Eşleşmedi | KONTROL ET | Kurulu bir programla eşleşmedi. 3. bölümde de silinebilir öğe olarak görünür |

Eşleştirmenin nasıl yapıldığı [aşağıda](#artık-klasör-tespiti-nasıl-çalışır) anlatılıyor.

---

## Asla silme listesine girmeyenler (DOKUNMA)

Aşağıdaki yollar ve altındaki her şey **koda gömülü olarak korunur.** Raporun 2. bölümünde boyutlarıyla gösterilir, ama silme listesine hiçbir koşulda giremez ve silme sırasında bir kez daha kontrol edilir:

| Yol | Ne olduğu |
|---|---|
| `%LOCALAPPDATA%\Microsoft\WinGet` | Önbellek gibi görünse de **winget ile kurulan programların kendisi** buradadır (örn. Deno, FFmpeg, yt-dlp). Silinirse bu programlar çalışmaz |
| `%WINDIR%` (tümü) | Windows. Özellikle `Windows\Installer` silinirse programlar güncellenemez ve kaldırılamaz |
| `%ProgramFiles%\WindowsApps` | Store uygulamalarının programları. Elle silinirse uygulamalar ve Microsoft Store bozulur |
| `%ProgramFiles%\NVIDIA Corporation\Installer2` | NVIDIA bileşenlerinin kaldırma ve onarma dosyaları |
| `%ProgramData%\LGHUB\depots` | Logitech G HUB'ın çalışan paketi |
| `%APPDATA%\uv` | uv'nin ayarları ve uv ile kurulan araçlar (önbellek değil) |
| `~\.cache\codex-runtimes` | Codex'in çalışma ortamı |
| `~\.claude`, `%TEMP%\claude`, Claude uygulama klasörleri | Claude Code ve Claude masaüstü uygulamasının verileri |

Korumalı yol kontrolü tam yol eşleşmesiyle yapılır: `WinGet` korunur ama `WinGetX` gibi benzer adlı bir klasör korunmuş sayılmaz.

2. bölümde bunlara ek olarak şunlar da DOKUNMA etiketiyle gösterilir:

- **Sistem sürücüsündeki büyük oyunlar** (5 GB üstü Steam oyunları): kurulu oyun dosyaları
- **Store uygulamalarının verileri** (`%LOCALAPPDATA%\Packages` altında 500 MB üstü): kurulu uygulamaların verileri
- **`hiberfil.sys` ve `pagefile.sys`**: Windows'un yönettiği sistem dosyaları
- **Geri yükleme noktaları**: yalnızca yönetici olarak çalıştırıldığında ölçülür

---

## Artık klasör tespiti nasıl çalışır?

Program önce bilgisayarda kurulu olan her şeyin bir **isim listesini** çıkarır:

1. **Kayıt defteri:** `HKLM` ve `HKCU` altındaki `Uninstall` anahtarlarındaki program adları, yayıncılar ve kurulum klasörlerinin adları
2. **Program klasörleri:** `Program Files`, `Program Files (x86)` ve `%LOCALAPPDATA%\Programs` altındaki klasörler ve bir alt seviyeleri (örn. `Electronic Arts\EA Desktop`)
3. **Microsoft Store uygulamaları:** `Get-AppxPackage` ile
4. **Steam oyunları:** `libraryfolders.vdf` okunarak **tüm Steam kütüphaneleri** (D: gibi diğer sürücüler dahil)
5. **Epic Games oyunları:** Launcher manifest dosyalarından
6. **Çalışan işlemler:** O an açık olan programların adları

Sonra her `AppData` klasörü için:

- İsimler normalleştirilir: küçük harfe çevrilir, Türkçe karakterler sadeleştirilir, harf ve rakam dışındaki her şey atılır (`EA SPORTS FC 26` → `easportsfc26`).
- Önce birebir eşleşme aranır. Yoksa klasör adı bir programın adının içinde geçiyorsa (veya tersi) **kurulu** sayılır. Raporda eşleşen programın adı gösterilir.
- Klasör adı programdan farklıysa **takma ad tablosuna** bakılır (örn. `TS4` → The Sims 4).
- `Şirket\Oyun` yapısındaki klasörlerde (özellikle `LocalLow`) **alt klasörlerden biri** kurulu bir programla eşleşiyorsa kurulu sayılır. Örneğin `LocalLow\Curve Animation\Liar's Bar`, Liar's Bar kuruluysa eşleşir.
- Windows'un kendi klasörleri (`Microsoft`, `Packages`, `Temp`...) ve birçok oyunun ortak kullandığı hile önleyiciler (`BattlEye`, `EasyAntiCheat`) **Sistem** olarak işaretlenir.
- Geliştirici araçlarına ait klasörler (`Pub`, `kotlin`, `GitHub CLI`...) için ilgili komutun (`dart`, `kotlin`, `gh`...) sistemde olup olmadığına bakılır.

Bu yöntem bilerek **temkinli** kurulmuştur: Emin olamadığında klasörü kurulu sayar. Yani bazı gerçek artıklar "Kurulu" görünebilir. Bunun tersi, yani kurulu bir programın klasörünün GÜVENLİ diye gösterilmesi ise olmaz; eşleşmeyen klasörler her zaman KONTROL ET etiketiyle gelir.

---

## Silme yöntemleri

| | Geri Dönüşüm Kutusu (`1`) | Kalıcı (`2`) |
|---|---|---|
| Geri alınabilir mi? | ✅ Evet, Geri Dönüşüm Kutusu'ndan | ❌ Hayır |
| Diskte yer açar mı? | ❌ **Hayır**, kutu boşaltılana kadar | ✅ Evet, hemen |

> **Not:** `uv`, `npm`, `pip`, `yarn`, `go` ve `dotnet` önbellekleri seçilen yöntemden bağımsız olarak aracın kendi komutuyla **kalıcı** olarak temizlenir. Özet ekranında bu durum ayrıca belirtilir.

Silme bittikten sonra her öğenin yolları tekrar kontrol edilir:
- Hepsi gittiyse **TAMAM** yazılır.
- Bir kısmı kaldıysa **KISMEN** yazılır. Bu genellikle dosyanın o an açık bir program tarafından kullanıldığı anlamına gelir.

---

## CSV raporu

`-Csv rapor.csv` verildiğinde iki dosya oluşur:

| Dosya | İçerik | Sütunlar |
|---|---|---|
| `rapor.csv` | Silinebilecek öğeler (3. bölüm) | `Ad`, `Risk`, `Kategori`, `MB`, `Not`, `Yollar` |
| `rapor-envanter.csv` | Taranan her şey (1. ve 2. bölüm) | `Bolum`, `Ad`, `Etiket`, `Aciklama`, `MB`, `Yol` |

Dosyalar UTF-8 olarak kaydedilir ve Excel'de doğrudan açılabilir.

---

## Testler

Testler gerçek dosyalara **dokunmaz**. `%TEMP%\DiskTemizleyiciTest` altında sahte klasörler oluşturur, menüye otomatik cevaplar verir ve sonucu kontrol eder.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Test-DiskTemizleyici.ps1
```

| Grup | Test edilenler |
|---|---|
| Seçim çözümleme | `1,3,5-7` doğru çözülüyor mu? Tek başına `1` geçerli mi? Aralık dışı, harf ve ters aralık reddediliyor mu? |
| Korumalı yollar | WinGet ve Windows korunuyor mu? Benzer adlı klasör yanlışlıkla korunuyor mu? Korumalı yol listeye eklenebiliyor mu? |
| Onay akışı | "hayır" cevabı, geçersiz yöntem ve geçersiz seçim hiçbir şey sildirmiyor mu? |
| Silme | `g` sadece GÜVENLİ öğeleri mi siliyor? Numara seçimi sadece o öğeyi mi siliyor? Geri Dönüşüm Kutusu çalışıyor mu? |
| Çoklu tur | Silinen öğe listeden çıkıyor mu? İkinci turdaki numaralar doğru öğeyi mi gösteriyor? |
| Eklenti sürümleri | En yeni sürüm korunuyor mu? Sürümler sayısal mı karşılaştırılıyor? Farklı platformlar ayrı mı sayılıyor? |
| Android imajları | Emülatör yokken tüm imajlar, emülatör varken sadece kullanılmayanlar mı bulunuyor? |
| Program eşleştirme | Birebir ve kısmi eşleşme, 3 harfli adların sadece birebir eşleşmesi, kayıt defteri önceliği, program alt klasörlerinin ("help" gibi) sadece birebir eşleşmesi, tanınmayan klasör, Türkçe karakter sadeleştirme |
| Çift sayım | Listedeki bir klasörün alt klasörü ayrıca listeye ekleniyor mu? |
| Etiketler | DOKUNMA öğeleri silme listesine girebiliyor mu? |

Beklenen çıktının sonu:

```text
GECTI  Bilgi öğesi silme listesine eklenmez
Toplam: 33/33
```

Herhangi bir test başarısız olursa betik `1` çıkış koduyla biter, böylece CI'da da kullanılabilir.

---

## Özelleştirme

Tüm ayarlar `DiskTemizleyici.ps1` dosyasının içindedir. Değişiklikten sonra testleri çalıştırmayı unutma.

### Bir yolu korumaya almak

`$script:Korumali` listesine ekle:

```powershell
$script:Korumali = @(
    "$L\Microsoft\WinGet",
    ...
    "$U\OnemliKlasorum"      # <- yeni
)
```

### Yanlış eşleşen bir klasörü düzeltmek

Klasör adı programın adından farklıysa `$script:TakmaAdlar` tablosuna ekle:

```powershell
$script:TakmaAdlar = @{
    'TS4' = 'thesims4'
    ...
    'KlasorAdi' = 'programinadi'   # <- normalleştirilmiş hali: küçük harf, boşluksuz
}
```

Klasör hiçbir programa ait değilse ama Windows bileşeni gibi korunması gerekiyorsa `$script:SistemKlasorleri` listesine ekle.

### Bir geliştirici aracını tanıtmak

`$script:AracKlasorleri` tablosu klasör adını, varlığı kontrol edilecek komuta bağlar:

```powershell
$script:AracKlasorleri = @{
    'Pub' = 'dart'
    ...
    'cargo' = 'cargo'   # <- cargo kurulu değilse klasör "eşleşmedi" olarak listelenir
}
```

### Yeni bir önbellek kuralı eklemek

`Find-Onbellekler` fonksiyonuna bir `Add-Aday` satırı ekle:

```powershell
# Basit klasör silme
Add-Aday 'Örnek önbellek' @("$L\OrnekUygulama\Cache") 'GUVENLI' 'Önbellek' 'Kendini yeniden oluşturur'

# Aracın kendi komutuyla temizleme
if (Get-Command cargo -ErrorAction SilentlyContinue) {
    Add-Aday 'Cargo önbelleği' @("$U\.cargo\registry\cache") 'GUVENLI' 'Önbellek' 'cargo cache ile temizlenir' { cargo cache -a | Out-Host }
}
```

| Parametre | Açıklama |
|---|---|
| `Ad` | Listede görünecek isim |
| `Yollar` | Silinecek bir veya birden fazla yol. Var olmayan yollar otomatik atlanır |
| `Risk` | `GUVENLI` (ekranda GÜVENLİ) veya `KONTROL` (ekranda KONTROL ET) |
| `Kategori` | CSV raporunda görünür (Önbellek, Artık, Eski sürüm...) |
| `Not` | Listede adın altında görünen açıklama. Öneri değil, **olgu** yazılmalı ("Kendini yeniden oluşturur" gibi) |
| `Komut` | *(isteğe bağlı)* Klasörü silmek yerine çalıştırılacak temizleme komutu |

Korumalı bir yol içeren kural sessizce yok sayılır. Aynı yol iki farklı kuralda geçerse yalnızca ilki listelenir.

### Silme listesi dışında bilgi göstermek

`Find-Bilgiler` fonksiyonuna bir `Add-Bilgi` satırı ekle. Bu öğeler numarasız gösterilir ve seçilemez:

```powershell
Add-Bilgi 'Örnek klasör' (Get-Boyut @("C:\Ornek")) 'Ne olduğu ve silinirse ne olacağı'
```

---

## Sık sorulan sorular ve sorun giderme

<details>
<summary><b>"Bu sistemde betik çalıştırma devre dışı" hatası alıyorum</b></summary>

PowerShell varsayılan olarak `.ps1` dosyalarının çalışmasını engeller. `.bat` dosyasını kullan veya şu şekilde çalıştır:

```powershell
powershell -ExecutionPolicy Bypass -File .\DiskTemizleyici.ps1
```

Bu yalnızca o çalıştırma için geçerlidir, sistem ayarını değiştirmez.
</details>

<details>
<summary><b>"git is not recognized" hatası alıyorum</b></summary>

Bilgisayarda Git kurulu değil. Kurulum bölümündeki **Git olmadan** yollarından birini kullan veya Git'i kur:

```powershell
winget install --id Git.Git -e
```

Kurulumdan sonra PowerShell'i kapatıp yeniden aç.
</details>

<details>
<summary><b>Türkçe karakterler bozuk görünüyor</b></summary>

`.ps1` dosyaları **UTF-8 BOM** ile kaydedilmelidir. PowerShell 5.1, BOM olmayan dosyaları yanlış kodlamayla okur. Dosyayı düzenlediysen editöründe kodlamayı "UTF-8 with BOM" olarak kaydet. `.bat` dosyası konsolu UTF-8'e (`chcp 65001`) çevirir.
</details>

<details>
<summary><b>Bir uygulamanın içindeki terminalde farklı sonuç alıyorum</b></summary>

MSIX paketi olarak kurulan bazı uygulamaların (bazı AI asistanları ve editörler gibi) içindeki terminaller, `AppData` klasörünü **sanallaştırılmış** bir kopya olarak görür. Bu durumda gerçek önbellekler bulunamayabilir ve `uv cache clean` gibi komutlar "No cache found" diyebilir. Aracı **normal bir PowerShell veya Windows Terminal penceresinde** çalıştır.
</details>

<details>
<summary><b>Bazı öğeler "KISMEN" siliniyor</b></summary>

O öğedeki bazı dosyalar başka bir program tarafından kullanılıyor. Tarayıcı ve Electron önbelleklerinde bu sık görülür, çünkü bu programlar arka planda çalışmaya devam edebilir. İlgili program kapatıldıktan veya bilgisayar yeniden başlatıldıktan sonra tekrar denenebilir. `C:\ProgramData` altındaki öğeler için aracın **yönetici olarak** çalıştırılması gerekebilir.
</details>

<details>
<summary><b>NVIDIA paketi silindi ama birkaç gün sonra geri geldi</b></summary>

NVIDIA App'te otomatik sürücü indirme açıksa yeni sürümler kendiliğinden indirilir. Bu ayar NVIDIA App'te **Ayarlar → Hakkında** bölümündedir. Kurulu sürücü, paketin silinmesinden etkilenmez.
</details>

<details>
<summary><b>Geri Dönüşüm Kutusu'na gönderildi ama yer açılmadı</b></summary>

Bu normal. Dosyalar Geri Dönüşüm Kutusu boşaltılana kadar diskte kalır.
</details>

<details>
<summary><b>Gradle sürümü silindi, Android projesi derlenmiyor</b></summary>

İnternet bağlantısı varsa bir sonraki derlemede Gradle gerekli sürümü yeniden indirir; ilk derleme uzun sürer. Araç, projelerde kullanılan sürümleri KONTROL ET olarak işaretler. Ancak proje taranan klasörlerin dışındaysa sürüm GÜVENLİ görünebilir. Bu durumda proje klasörü `Find-Onbellekler` içindeki `$aramaYerleri` listesine eklenebilir.
</details>

<details>
<summary><b>Android sistem imajları silindi, emülatör açılmıyor</b></summary>

Araç yalnızca **hiçbir emülatörün kullanmadığı** imajları listeler. Silindikten sonra yeni bir emülatör oluşturulursa Android Studio gereken imajı **Device Manager → Create Device** adımında yeniden indirir. Uygulama derlemek için sistem imajı gerekmez.
</details>

<details>
<summary><b>Kurulu bir programın klasörü "eşleşmedi" (KONTROL ET) görünüyor</b></summary>

Klasör adı programın adından çok farklıysa eşleştirme başarısız olabilir. Klasör `$script:TakmaAdlar` tablosuna eklenerek düzeltilebilir (bkz. [Özelleştirme](#özelleştirme)). Bu tür durumları bir issue açarak bildirirsen takma ad tablosuna eklenebilir.
</details>

<details>
<summary><b>Tarama neden bu kadar uzun sürüyor?</b></summary>

Taranan her klasörün boyutu, içindeki tüm dosyalar sayılarak hesaplanır. Binlerce küçük dosya içeren klasörlerde (Gradle, npm, büyük oyunlar) bu birkaç dakika sürebilir. Hiçbir şey silinmediği için tarama istenildiği zaman `Ctrl + C` ile durdurulabilir.
</details>

<details>
<summary><b>Yanlışlıkla bir şey kalıcı olarak silindi</b></summary>

- **Önbellekler:** İlgili program gerektiğinde yeniden oluşturur.
- **Oyun ayarları ve kayıtları:** Steam, Epic ve EA birçok oyunun kayıtlarını bulutta da tutar.
- **Diğerleri:** Windows'un **Dosya Geçmişi** veya **Sistem Geri Yükleme** özelliği açıksa oradan geri alınabilir.
</details>

---

## Bilinen sınırlamalar

- **Sadece Windows.** macOS ve Linux desteklenmez.
- **Eşleştirme isme dayanır.** Klasör adı programdan çok farklıysa ve takma ad tablosunda yoksa yanlış sonuç çıkabilir. Bu yüzden eşleşmeyen klasörler her zaman KONTROL ET etiketiyle gelir.
- **Sürücü sürümü tespiti NVIDIA'ya özgü.** AMD ve Intel sürücü paketleri taranmaz.
- **Taranan yerler sabit.** Önbellek konumları özel bir yere taşındıysa bulunamayabilir. `uv` ve `go` için aracın kendi komutu kullanıldığından taşınmış önbellekleri de bulunur.
- **Yönetici olmadan bazı alanlar ölçülemez.** Geri yükleme noktaları ve `WindowsApps` yalnızca yönetici olarak çalıştırıldığında ölçülür.
- **Menü, otomatik testlerde simüle edilmiş girdilerle test edilir.** Gerçek bir konsolda klavyeyle kullanım ayrıca otomatik test edilmez.
- **Sistem dosyalarına dokunmaz.** `hiberfil.sys`, `pagefile.sys` ve Windows Update önbelleği gibi dosyalar yalnızca bilgi olarak gösterilir.

## Proje yapısı

```text
disk-temizleyici/
├── DiskTemizleyici.ps1        # Programın kendisi: tarama, rapor, menü, silme
├── DiskTemizleyici.bat        # Çift tıklayarak başlatmak için
├── Test-DiskTemizleyici.ps1   # Otomatik testler (sahte klasörlerle)
├── README.md                  # Bu dosya
├── LICENSE                    # MIT lisansı
└── .gitattributes             # Windows satır sonlarını korur
```

`DiskTemizleyici.ps1` içindeki ana fonksiyonlar:

| Fonksiyon | Görevi |
|---|---|
| `Find-Artiklar` | Her AppData klasörünü ölçer, kurulu programlarla eşleştirir ve envantere ekler |
| `Find-Onbellekler` | Önbellek, eski sürüm, emülatör ve kurulum dosyası kurallarını çalıştırır |
| `Find-Bilgiler` | Silme listesine alınmayan (DOKUNMA) öğeleri toplar |
| `Get-KuruluIndeks` | Kurulu programların isim listesini çıkarır |
| `Find-Eslesme` | Bir klasör adını kurulu programlarla eşleştirir, eşleşen programın adını döndürür |
| `Get-EskiSurumler` | Eklenti klasör adlarından eski sürümleri bulur |
| `Get-KullanilmayanImajlar` | Hiçbir emülatörün kullanmadığı Android sistem imajlarını bulur |
| `Get-SteamKutuphaneleri` | Bütün Steam kütüphanelerinin yollarını döndürür |
| `Get-Boyut` | Klasör boyutunu hızlı ölçer ve sonucu hafızada tutar |
| `Add-Aday` / `Add-Bilgi` | Silme listesine / bilgi listesine öğe ekler |
| `Test-Korumali` | Bir yolun korumalı olup olmadığını kontrol eder |
| `ConvertFrom-Secim` | `1,3,5-7` gibi girdileri numara listesine çevirir |
| `Show-Envanter` / `Show-Bilgiler` / `Show-Liste` | Raporun üç bölümünü ekrana yazar |
| `Invoke-Menu` | Seçim, yöntem ve onay döngüsünü yönetir |
| `Remove-Aday` | Siler ve sonucu doğrular |

## Katkıda bulunma

Katkılar memnuniyetle karşılanır. Özellikle şunlar işe yarar:

- Yanlış eşleşen klasörler için **takma ad** eklemeleri
- Yeni **önbellek kuralları** (Rust, Unity, Unreal, Adobe...)
- AMD / Intel sürücü paketi desteği

Pull request göndermeden önce:

1. Yeni bir kural eklediysen, kuralın **korumalı yolları** etkilemediğinden emin ol.
2. Emin olunmayan her şeyi `KONTROL` olarak işaretle. `GUVENLI` etiketi yalnızca **kendini yeniden oluşturan** veya zaten kullanılmış dosyalar içindir.
3. Açıklamalara öneri değil **olgu** yaz: "Kendini yeniden oluşturur" doğru, "Silebilirsin" yanlış.
4. Testleri çalıştır ve hepsinin geçtiğinden emin ol:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\Test-DiskTemizleyici.ps1
   ```
5. `.ps1` dosyalarını **UTF-8 BOM** ile kaydet.

## Sorumluluk reddi

Bu araç bir **tarama ve raporlama** aracıdır; öneri veya tavsiye vermez. Gösterilen etiketler (GÜVENLİ, KONTROL ET, DOKUNMA) ve açıklamalar yalnızca dosyaların genel türü hakkında bilgi amaçlıdır ve her bilgisayar için doğru olmayabilir. Hangi dosyanın silineceğine dair karar ve bu kararın sonuçlarına ilişkin sorumluluk tamamen kullanıcıya aittir. Silme işlemi yalnızca kullanıcının açık onayıyla (`EVET` yazılarak) gerçekleşir.

Yazılım, MIT lisansı kapsamında "olduğu gibi", hiçbir garanti olmaksızın sunulmaktadır. Geliştiriciler, yazılımın kullanımından doğabilecek veri kaybı veya diğer zararlardan sorumlu tutulamaz.

## Lisans

[MIT](LICENSE) © 2026 GeneralBuSa
