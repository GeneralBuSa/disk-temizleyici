# 🧹 Disk Temizleyici

**Windows için onaylı, güvenli disk temizleme aracı.**
Bilgisayarındaki gereksiz önbellekleri, eski sürüm dosyalarını ve kaldırılmış programlardan kalan klasörleri bulur. Bulduklarını boyuta göre sıralar ve **hiçbir şeyi sen onaylamadan silmez.**

![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D6)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE)
![Bağımlılık](https://img.shields.io/badge/bağımlılık-yok-brightgreen)
![Lisans](https://img.shields.io/badge/lisans-MIT-blue)

---

## İçindekiler

- [Neden bu araç?](#neden-bu-araç)
- [Temel ilkeler](#temel-ilkeler)
- [Özellikler](#özellikler)
- [Gereksinimler](#gereksinimler)
- [Kurulum](#kurulum)
- [Kullanım](#kullanım)
  - [Çift tıklayarak](#1-çift-tıklayarak-önerilen)
  - [PowerShell'den](#2-powershellden)
  - [Parametreler](#parametreler)
  - [Menü adım adım](#menü-adım-adım)
  - [Örnek çıktı](#örnek-çıktı)
- [Neleri tarar?](#neleri-tarar)
- [Etiketler: GÜVENLİ ve KONTROL](#etiketler-güvenli-ve-kontrol)
- [Asla dokunulmayan yollar](#asla-dokunulmayan-yollar)
- [Artık klasör tespiti nasıl çalışır?](#artık-klasör-tespiti-nasıl-çalışır)
- [Silme yöntemleri](#silme-yöntemleri)
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

Windows'ta zamanla gigabaytlarca gereksiz dosya birikir, ama bunların çoğu Windows'un kendi **Disk Temizleme** aracının hiç bakmadığı yerlerdedir:

- Geliştirici araçlarının önbellekleri (`uv`, `npm`, `pip`, `Gradle`, Dart, Playwright)
- NVIDIA App'in indirip kurduktan sonra silmediği **sürücü paketleri** (her biri ~4 GB)
- Android Studio'nun **eski sürümlerinden** kalan ayar klasörleri
- Kaldırdığın oyun ve programların `AppData` içinde bıraktığı **artık klasörler**
- `Downloads` klasöründe unutulan büyük **kurulum dosyaları ve arşivler**

Bu araç bunları bir arada bulur. Ama "temizleyici" programların en büyük riski, yanlış şeyi silmeleridir. Bu yüzden araç **yalnızca öneri yapar, kararı sana bırakır.**

## Temel ilkeler

1. **Onaysız silme yok.** Her silme işleminden önce silinecek her yol ekranda gösterilir ve devam etmek için `EVET` yazman gerekir.
2. **Emin olunmayan her şey "KONTROL" olarak işaretlenir.** Kendini yeniden oluşturmayan, içinde kayıt veya ayar olabilecek hiçbir şey "GÜVENLİ" sayılmaz.
3. **Kritik yollar koda gömülü bir korumayla engellenir.** Bu yollar hem listeye girmez hem de silme anında bir kez daha kontrol edilir.
4. **Silme sonrası doğrulama.** Her öğe silindikten sonra gerçekten gidip gitmediği kontrol edilir ve kilitli dosya kalırsa bildirilir.
5. **Araçların kendi temizleme komutu tercih edilir.** `uv`, `npm` ve `pip` önbellekleri doğrudan silinmez, aracın kendi komutuyla temizlenir.

## Özellikler

- 🔍 **Kapsamlı tarama:** 10'dan fazla önbellek türü ve kurulu programlarla eşleşmeyen `AppData` klasörleri
- 📊 **Boyuta göre sıralama:** En çok yer kaplayan öğe en üstte
- 🟢🟡 **Risk etiketleri:** Her öğenin yanında neden önerildiğini açıklayan bir not
- 🎯 **Esnek seçim:** `1,3,5-7` gibi numaralar veya tek tuşla tüm GÜVENLİ öğeler
- ♻️ **İki silme yöntemi:** Geri Dönüşüm Kutusu (geri alınabilir) veya kalıcı silme
- 🛡️ **Korumalı yollar:** winget programları, Windows Installer önbelleği ve benzerleri asla silinmez
- 📏 **Açılan yer raporu:** Her turdan sonra C: sürücüsünde ne kadar yer açıldığı gösterilir
- 📄 **CSV rapor:** Bulguları Excel'de açılabilecek bir dosyaya kaydetme
- 🧪 **Testli:** Seçim, onay ve koruma mantığı otomatik testlerle doğrulanır
- 📦 **Bağımlılık yok:** Windows'ta yerleşik gelen PowerShell 5.1 ile çalışır, kurulum gerektirmez

## Gereksinimler

| Gereksinim | Not |
|---|---|
| Windows 10 veya 11 | Windows 11 üzerinde geliştirildi ve test edildi |
| PowerShell 5.1 veya üstü | Windows ile birlikte gelir, ek kurulum gerekmez |
| Yönetici yetkisi | **Gerekmez.** Yalnızca `C:\ProgramData` altındaki bazı dosyalar (örn. NVIDIA paketleri) için gerekebilir |

## Kurulum

**Git ile:**

```bash
git clone https://github.com/GeneralBuSa/disk-temizleyici.git
cd disk-temizleyici
```

**Git olmadan:** GitHub sayfasında **Code → Download ZIP**'e tıkla ve ZIP'i bir klasöre çıkar.

> ⚠️ ZIP olarak indirdiysen Windows dosyaları "internetten indirildi" diye işaretleyebilir. Bunu kaldırmak için klasörde PowerShell açıp şunu çalıştır:
>
> ```powershell
> Get-ChildItem | Unblock-File
> ```

## Kullanım

### 1. Çift tıklayarak (önerilen)

`DiskTemizleyici.bat` dosyasına çift tıkla. PowerShell'in betik çalıştırma kısıtlamasını yalnızca bu çalıştırma için aşar, sistem ayarlarını değiştirmez.

### 2. PowerShell'den

Klasörde boş bir yere **Shift + sağ tık → PowerShell penceresini burada aç** de ve şunu çalıştır:

```powershell
powershell -ExecutionPolicy Bypass -File .\DiskTemizleyici.ps1
```

### Parametreler

| Parametre | Açıklama | Örnek |
|---|---|---|
| *(parametresiz)* | Tara, listele, seçim menüsünü aç | `.\DiskTemizleyici.ps1` |
| `-SadeceRapor` | Sadece tara ve listele. Silme menüsü hiç açılmaz | `.\DiskTemizleyici.ps1 -SadeceRapor` |
| `-Csv <dosya>` | Listeyi ayrıca CSV dosyasına kaydet | `.\DiskTemizleyici.ps1 -Csv rapor.csv` |
| `-NoRun` | Sadece fonksiyonları yükler, hiçbir şey çalıştırmaz (testler için) | `. .\DiskTemizleyici.ps1 -NoRun` |

Parametreler birlikte kullanılabilir:

```powershell
.\DiskTemizleyici.ps1 -SadeceRapor -Csv "$env:USERPROFILE\Desktop\disk-raporu.csv"
```

`.bat` dosyası da parametreleri aktarır:

```bat
DiskTemizleyici.bat -SadeceRapor
```

### Menü adım adım

**1. Tarama.** Program açılınca tarama başlar. Klasör boyutları tek tek hesaplandığı için bilgisayarına göre **2-5 dakika** sürebilir. Pencereyi kapatma.

**2. Liste.** Bulunan her şey boyuta göre sıralanır. Her satırda numara, etiket, boyut, ad ve altında gri renkte bir açıklama bulunur.

**3. Seçim.** Ne silmek istediğini yaz:

| Girdi | Anlamı |
|---|---|
| `3` | Sadece 3 numara |
| `1,4,7` | 1, 4 ve 7 numara |
| `2-5` | 2'den 5'e kadar hepsi |
| `1,3,6-9` | Karışık kullanım |
| `g` | Tüm **GÜVENLİ** öğeler (KONTROL olanlar dahil edilmez) |
| `q` veya boş Enter | Çıkış |

Geçersiz bir girdi (olmayan bir numara, harf, ters aralık) hiçbir şey seçmez ve menü tekrar gösterilir.

**4. Özet.** Seçtiğin her öğe, silinecek yollarıyla birlikte listelenir ve toplam boyut gösterilir.

**5. Yöntem.** `1` Geri Dönüşüm Kutusu veya `2` Kalıcı silme. Başka bir şey yazarsan işlem iptal edilir.

**6. Onay.** `EVET` yaz (büyük-küçük harf fark etmez). **Başka herhangi bir cevap işlemi iptal eder ve hiçbir şey silinmez.**

**7. Sonuç.** Her öğe için `TAMAM` veya `KISMEN` yazılır ve açılan toplam yer gösterilir. Silinen öğeler listeden çıkar, menü kalan öğelerle tekrar açılır.

### Örnek çıktı

```text
Disk Temizleyici - hiçbir şey onayın olmadan silinmez.
Taranıyor (birkaç dakika sürebilir)...
  Önbellekler taranıyor...
  Kurulu programlar okunuyor...
  AppData klasörleri kurulu programlarla karşılaştırılıyor...

 No  Durum         Boyut  Ad / Not
------------------------------------------------------------------------------------------
  1  KONTROL      4,2 GB  Gradle 8.14
                         Bir projen bu sürümü kullanıyor; silinirse derlemede yeniden iner
  2  GÜVENLİ      3,9 GB  NVIDIA sürücü paketi 621.24
                         Bu sürüm zaten kurulu
  3  GÜVENLİ      209 MB  Eski Android Studio verisi (AndroidStudio2025.3.2)
                         En yeni: AndroidStudio2025.3.3
  4  KONTROL      118 MB  Downloads: DiscordSetup.exe
                         Büyük kurulum dosyası veya arşiv
  5  GÜVENLİ      107 MB  pip önbelleği
                         pip cache purge ile temizlenir
  6  GÜVENLİ       71 MB  Çökme kayıtları (10 dosya)
                         Programların çökme dökümleri
  7  KONTROL        3 MB  Local\Cloudflare
                         Kurulu bir programla eşleşmedi; içinde oyun kaydı/ayar olabilir
  8  GÜVENLİ           0  Geçici tw-*.tmp klasörleri (336 adet)
                         Boş geçici klasörler
------------------------------------------------------------------------------------------
GÜVENLİ toplam: 4,3 GB    KONTROL toplam: 4,3 GB

Seçim: numaralar (örn. 1,3,5-7)  |  g = tüm GÜVENLİ olanlar  |  q = çıkış
Seçimin: 2,6

Silinecekler:
  - NVIDIA sürücü paketi 621.24  (3,9 GB)
      C:\ProgramData\NVIDIA Corporation\NVIDIA App\UpdateFramework\ota-artifacts\grd\...
  - Çökme kayıtları (10 dosya)  (71 MB)
      ...
Toplam: 4,0 GB
Nasıl silinsin? 1 = Geri Dönüşüm Kutusu (geri alınabilir, yer açmaz)  2 = Kalıcı sil: 2
Onaylıyor musun? Devam etmek için EVET yaz (KALICI): EVET
Siliniyor: NVIDIA sürücü paketi 621.24... TAMAM
Siliniyor: Çökme kayıtları (10 dosya)... TAMAM
C: sürücüsünde açılan yer: 4,0 GB
```

---

## Neleri tarar?

### Önbellekler ve geçici dosyalar

| Öğe | Konum | Etiket | Nasıl temizlenir |
|---|---|---|---|
| **uv önbelleği** | `uv cache dir` komutunun gösterdiği yer | GÜVENLİ | `uv cache clean` |
| **npm önbelleği** | `%LOCALAPPDATA%\npm-cache\_cacache` | GÜVENLİ | `npm cache clean --force` |
| **pip önbelleği** | `%LOCALAPPDATA%\pip\cache` | GÜVENLİ | `python -m pip cache purge` |
| **Dart analiz önbelleği** | `%LOCALAPPDATA%\.dartServer` | GÜVENLİ | Klasör silinir, Dart yeniden oluşturur |
| **Playwright tarayıcıları** | `%LOCALAPPDATA%\ms-playwright`, `ms-playwright-go` | GÜVENLİ | Klasör silinir, gerekirse `playwright install` |
| **Çökme kayıtları** | `%LOCALAPPDATA%\CrashDumps\*` | GÜVENLİ | Dosyalar silinir |
| **Geçici `tw-*.tmp` klasörleri** | `%LOCALAPPDATA%\tw-*.tmp` | GÜVENLİ | Klasörler silinir |

> `uv`, `npm` ve `pip` önbellekleri yalnızca ilgili araç kuruluysa listelenir, çünkü temizleme aracın kendi komutuyla yapılır. Bu üç önbellek 1 MB'tan küçükse (yani zaten temizse) listeye eklenmez.

### Eski sürümler ve kurulum dosyaları

| Öğe | Nasıl karar verir | Etiket |
|---|---|---|
| **Gradle sürümleri** (`~\.gradle\caches\<sürüm>` ve `wrapper\dists`) | Projelerindeki `gradle-wrapper.properties` dosyalarını tarar. Hiçbir projenin kullanmadığı sürüm GÜVENLİ, kullanılan sürüm KONTROL olur | GÜVENLİ / KONTROL |
| **Eski Android Studio verisi** (`AndroidStudio20xx.x.x`) | Hem `Local\Google` hem `Roaming\Google` altında en yeni sürüm dışındakileri önerir | GÜVENLİ |
| **NVIDIA sürücü paketleri** (`NVIDIA App\UpdateFramework\ota-artifacts\grd`) | Paketteki `.exe` adından sürümü okur ve kurulu sürücüyle karşılaştırır. Kurulu sürüm GÜVENLİ, kurulmamış güncelleme KONTROL olur | GÜVENLİ / KONTROL |
| **Android emülatörleri** (`~\.android\avd\*.avd`) | Her emülatörü ayrı listeler | KONTROL |
| **Downloads'taki büyük dosyalar** | `.exe .msi .zip .rar .7z .iso`, 50 MB'tan büyük ve 30 günden eski. Arşivin çıkarılmış hali yanındaysa bunu nota yazar | KONTROL |

Gradle projeleri şu klasörlerde aranır (6 seviye derinliğe kadar): `StudioProjects`, `Developer`, `Documents`, `Downloads`, `Desktop`, `source`.

### Kaldırılmış programların artıkları

`AppData\Local`, `AppData\LocalLow` ve `AppData\Roaming` altındaki her klasör, bilgisayarda kurulu programlarla karşılaştırılır. Eşleşmeyenler **KONTROL** etiketiyle listelenir. Ayrıntılar için [Artık klasör tespiti nasıl çalışır?](#artık-klasör-tespiti-nasıl-çalışır) bölümüne bak.

---

## Etiketler: GÜVENLİ ve KONTROL

| Etiket | Anlamı | Örnekler |
|---|---|---|
| 🟢 **GÜVENLİ** | Silinmesi hiçbir programı bozmaz. Dosyalar gerektiğinde kendiliğinden yeniden oluşur veya iner. En kötü ihtimalle bir sonraki kullanımda biraz bekleme olur | Önbellekler, kurulu sürücünün kurulum dosyası, çökme kayıtları |
| 🟡 **KONTROL** | Büyük ihtimalle gereksiz ama araç %100 emin değil. İçinde oyun kaydı, ayar veya tekrar indirilmesi zor bir dosya olabilir. **Silmeden önce ne olduğuna bak** | Artık klasörler, emülatörler, Downloads'taki dosyalar, kullanılan Gradle sürümü |

`g` kısayolu yalnızca GÜVENLİ öğeleri seçer. KONTROL öğeleri ancak numarasını elle yazarsan seçilir.

## Asla dokunulmayan yollar

Aşağıdaki yollar ve altındaki her şey **koda gömülü olarak korunur.** Listeye hiç eklenmez, silme sırasında da bir kez daha kontrol edilir:

| Yol | Neden korunuyor |
|---|---|
| `%LOCALAPPDATA%\Microsoft\WinGet` | Önbellek gibi görünse de **winget ile kurulan programların kendisi** buradadır (örn. Deno, FFmpeg, yt-dlp). Silinirse bu programlar çalışmaz |
| `%WINDIR%` (tümü) | Özellikle `Windows\Installer`: silinirse programlar güncellenemez ve kaldırılamaz |
| `%ProgramFiles%\NVIDIA Corporation\Installer2` | NVIDIA bileşenlerini kaldırma ve onarma dosyaları |
| `%ProgramData%\LGHUB\depots` | Logitech G HUB'ın çalışan paketi |
| `%APPDATA%\uv` | uv'nin ayarları ve uv ile kurulan araçlar (önbellek değil) |
| `~\.cache\codex-runtimes` | Codex'in çalışma ortamı |
| `~\.claude`, Claude uygulama klasörleri | Claude Code / Claude masaüstü verileri |

Korumalı yol kontrolü tam yol eşleşmesiyle yapılır: `WinGet` korunur ama `WinGetX` gibi benzer adlı bir klasör korunmuş sayılmaz.

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
- Klasör adı kurulu bir programın adının içinde geçiyorsa veya tersi doğruysa **kurulu** sayılır.
- Klasör adı programdan farklıysa **takma ad tablosuna** bakılır (örn. `TS4` → The Sims 4).
- `Şirket\Oyun` yapısındaki klasörlerde (özellikle `LocalLow`) **alt klasörlerden biri** kurulu bir programla eşleşiyorsa kurulu sayılır. Örneğin `LocalLow\Curve Animation\Liar's Bar`, Liar's Bar kuruluysa listelenmez.
- Windows'un kendi klasörleri (`Microsoft`, `Packages`, `Temp`...) ve birçok oyunun ortak kullandığı hile önleyiciler (`BattlEye`, `EasyAntiCheat`) hiç değerlendirilmez.
- Geliştirici araçlarına ait klasörler (`Pub`, `kotlin`, `GitHub CLI`...) için ilgili komutun (`dart`, `kotlin`, `gh`...) sistemde olup olmadığına bakılır.

Bu yöntem bilerek **temkinli** kurulmuştur: Emin olamadığında klasörü artık saymaz. Yani bazı gerçek artıklar listede görünmeyebilir. Bunun tersi, yani kurulu bir programın klasörünün GÜVENLİ diye gösterilmesi ise olmaz; artıklar her zaman KONTROL etiketiyle gelir.

---

## Silme yöntemleri

| | Geri Dönüşüm Kutusu (`1`) | Kalıcı (`2`) |
|---|---|---|
| Geri alınabilir mi? | ✅ Evet, Geri Dönüşüm Kutusu'ndan | ❌ Hayır |
| Diskte yer açar mı? | ❌ **Hayır**, kutuyu boşaltana kadar | ✅ Evet, hemen |
| Ne zaman kullanmalı? | KONTROL öğeleri, emin olmadığın şeyler | GÜVENLİ öğeler, önbellekler |

> **Not:** `uv`, `npm` ve `pip` önbellekleri seçtiğin yöntemden bağımsız olarak aracın kendi komutuyla **kalıcı** olarak temizlenir. Özet ekranında bu durum ayrıca belirtilir.

Silme bittikten sonra her öğenin yolları tekrar kontrol edilir:
- Hepsi gittiyse **TAMAM** yazılır.
- Bir kısmı kaldıysa **KISMEN** yazılır. Bu genellikle dosyanın o an açık bir program tarafından kullanıldığı anlamına gelir.

---

## Testler

Testler gerçek dosyalarına **dokunmaz**. `%TEMP%\DiskTemizleyiciTest` altında sahte klasörler oluşturur, menüye otomatik cevaplar verir ve sonucu kontrol eder.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Test-DiskTemizleyici.ps1
```

Test edilen durumlar:

| Grup | Test |
|---|---|
| Seçim çözümleme | `1,3,5-7` doğru çözülüyor mu? Tek başına `1` geçerli mi? Aralık dışı, harf ve ters aralık reddediliyor mu? |
| Korumalı yollar | WinGet ve Windows korunuyor mu? Benzer adlı klasör yanlışlıkla korunuyor mu? Korumalı yol listeye eklenebiliyor mu? |
| Onay akışı | "hayır" cevabı, geçersiz yöntem ve geçersiz seçim hiçbir şey sildirmiyor mu? |
| Silme | `g` sadece GÜVENLİ öğeleri mi siliyor? Numara seçimi sadece o öğeyi mi siliyor? Geri Dönüşüm Kutusu çalışıyor mu? |
| Çoklu tur | Silinen öğe listeden çıkıyor mu? İkinci turdaki numaralar doğru öğeyi mi gösteriyor? |

Beklenen çıktı:

```text
GECTI  Seçim 1,3,5-7 -> 0,2,4,5,6
GECTI  Tek başına 1 seçimi geçerli
...
GECTI  Silinen listeden çıkar, ikinci turda yeni 1 (B) silinir
Toplam: 15/15
```

Herhangi bir test başarısız olursa betik `1` çıkış koduyla biter, böylece CI'da da kullanılabilir.

---

## Özelleştirme

Tüm ayarlar `DiskTemizleyici.ps1` dosyasının içindedir.

### Bir yolu korumaya almak

`$script:Korumali` listesine ekle:

```powershell
$script:Korumali = @(
    "$L\Microsoft\WinGet",
    ...
    "$U\OnemliKlasorum"      # <- yeni
)
```

### Yanlış alarm veren bir klasörü düzeltmek

Klasör adı programın adından farklıysa `$script:TakmaAdlar` tablosuna ekle:

```powershell
$script:TakmaAdlar = @{
    'TS4' = 'thesims4'
    ...
    'KlasorAdi' = 'programinadi'   # <- normalleştirilmiş hali: küçük harf, boşluksuz
}
```

Klasör hiçbir programa ait değilse ama silinmemesi gerekiyorsa (Windows bileşeni gibi) `$script:SistemKlasorleri` listesine ekle.

### Bir geliştirici aracını tanıtmak

`$script:AracKlasorleri` tablosu klasör adını, varlığı kontrol edilecek komuta bağlar:

```powershell
$script:AracKlasorleri = @{
    'Pub' = 'dart'
    ...
    'go-build' = 'go'   # <- go kurulu değilse klasör artık olarak listelenir
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

`Add-Aday` parametreleri:

| Parametre | Açıklama |
|---|---|
| `Ad` | Listede görünecek isim |
| `Yollar` | Silinecek bir veya birden fazla yol. Var olmayan yollar otomatik atlanır |
| `Risk` | `GUVENLI` veya `KONTROL` |
| `Kategori` | CSV raporunda görünür (Önbellek, Artık, Eski sürüm...) |
| `Not` | Listede adın altında görünen açıklama |
| `Komut` | *(isteğe bağlı)* Klasörü silmek yerine çalıştırılacak temizleme komutu |

Korumalı bir yol içeren kural sessizce yok sayılır. Değişiklikten sonra testleri çalıştırmayı unutma.

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
<summary><b>Türkçe karakterler bozuk görünüyor</b></summary>

`.ps1` dosyaları **UTF-8 BOM** ile kaydedilmelidir. PowerShell 5.1, BOM olmayan dosyaları yanlış kodlamayla okur. Dosyayı düzenlediysen editöründe kodlamayı "UTF-8 with BOM" olarak kaydet. `.bat` dosyası konsolu UTF-8'e (`chcp 65001`) çevirir.
</details>

<details>
<summary><b>Bir uygulamanın içindeki terminalde farklı sonuç alıyorum</b></summary>

Microsoft Store'dan veya MSIX paketi olarak kurulan bazı uygulamaların (örneğin bazı AI asistanları ve editörler) içindeki terminaller, `AppData` klasörünü **sanallaştırılmış** bir kopya olarak görür. Bu durumda gerçek önbellekleri bulamayabilir ve `uv cache clean` gibi komutlar "No cache found" diyebilir. Aracı her zaman **normal bir PowerShell veya Windows Terminal penceresinde** çalıştır.
</details>

<details>
<summary><b>Bazı öğeler "KISMEN" siliniyor</b></summary>

O öğedeki bazı dosyalar başka bir program tarafından kullanılıyor. İlgili programı kapat (veya bilgisayarı yeniden başlat) ve tekrar dene. `C:\ProgramData` altındaki öğeler için aracı **yönetici olarak** çalıştırman gerekebilir: `.bat` dosyasına sağ tık → **Yönetici olarak çalıştır**.
</details>

<details>
<summary><b>NVIDIA paketini sildim ama birkaç gün sonra geri geldi</b></summary>

NVIDIA App ayarlarında otomatik sürücü indirme açıksa yeni sürümleri kendiliğinden indirir. Bunu önlemek için NVIDIA App'te **Ayarlar → Hakkında** bölümünden otomatik indirmeyi kapatabilirsin. Kurulu sürücün paketin silinmesinden etkilenmez.
</details>

<details>
<summary><b>Geri Dönüşüm Kutusu'na gönderdim ama yer açılmadı</b></summary>

Bu normal. Dosyalar Geri Dönüşüm Kutusu boşaltılana kadar diskte kalır. Silinen dosyalarla ilgili bir sorun olmadığından emin olunca kutuyu boşalt.
</details>

<details>
<summary><b>Gradle sürümünü sildim, Android projem derlenmiyor</b></summary>

İnternet bağlantın varsa bir sonraki derlemede Gradle gerekli sürümü yeniden indirir; ilk derleme biraz uzun sürer. Araç, projelerinde kullanılan sürümleri KONTROL olarak işaretler; ancak projen taranan klasörlerin dışındaysa sürüm GÜVENLİ görünebilir. Bu durumda proje klasörünü `Find-Onbellekler` içindeki `$aramaYerleri` listesine ekle.
</details>

<details>
<summary><b>Tarama neden bu kadar uzun sürüyor?</b></summary>

Her öğenin boyutu, içindeki tüm dosyalar tek tek sayılarak hesaplanır. Binlerce küçük dosya içeren önbelleklerde (Gradle, npm) bu birkaç dakika sürebilir. Hiçbir şey silinmediği için taramayı istediğin zaman `Ctrl + C` ile durdurabilirsin.
</details>

<details>
<summary><b>Yanlışlıkla bir şeyi kalıcı olarak sildim</b></summary>

- **Önbellekler:** Endişelenme, ilgili program gerektiğinde yeniden oluşturur.
- **Oyun ayarları/kayıtları:** Steam, Epic ve EA çoğu oyunun kayıtlarını bulutta da tutar. Oyunu açtığında bulut kaydı geri yüklenebilir.
- **Diğerleri:** Windows'un **Dosya Geçmişi** veya **Sistem Geri Yükleme** açıksa oradan geri almayı deneyebilirsin.

Bu yüzden KONTROL öğelerinde **Geri Dönüşüm Kutusu** seçeneğini kullanmanı öneririz.
</details>

---

## Bilinen sınırlamalar

- **Sadece Windows.** macOS ve Linux desteklenmez.
- **Artık tespiti isim eşleştirmesine dayanır.** Klasör adı programdan çok farklıysa ve takma ad tablosunda yoksa yanlış alarm verebilir. Bu yüzden artıklar her zaman KONTROL etiketiyle gelir.
- **Sürücü sürümü tespiti NVIDIA'ya özgü.** AMD ve Intel sürücü paketleri taranmaz.
- **Taranan yerler sabit.** Önbellek konumlarını özel bir yere taşıdıysan (örn. `UV_CACHE_DIR` dışında bir ortam değişkeniyle) araç bunları bulamayabilir. `uv` için `uv cache dir` komutu kullanıldığından taşınmış uv önbelleği bulunur.
- **Menü, otomatik testlerde simüle edilmiş girdilerle test edilir.** Gerçek bir konsolda klavyeyle kullanım ayrıca otomatik test edilmez. Bir sorun görürsen lütfen bildir.
- **Sistem dosyalarına dokunmaz.** `hiberfil.sys`, `pagefile.sys`, Windows Update önbelleği gibi sistem dosyaları için Windows'un kendi **Disk Temizleme** aracını kullan.

## Proje yapısı

```text
disk-temizleyici/
├── DiskTemizleyici.ps1        # Programın kendisi: tarama, liste, menü, silme
├── DiskTemizleyici.bat        # Çift tıklayarak başlatmak için
├── Test-DiskTemizleyici.ps1   # Otomatik testler (sahte klasörlerle)
├── README.md                  # Bu dosya
├── LICENSE                    # MIT lisansı
└── .gitattributes             # Windows satır sonlarını korur
```

`DiskTemizleyici.ps1` içindeki ana fonksiyonlar:

| Fonksiyon | Görevi |
|---|---|
| `Find-Onbellekler` | Önbellek, eski sürüm ve kurulum dosyası kurallarını çalıştırır |
| `Find-Artiklar` | AppData klasörlerini kurulu programlarla karşılaştırır |
| `Get-KuruluIndeks` | Kurulu programların isim listesini çıkarır |
| `Test-Eslesme` | Bir klasör adının kurulu bir programla eşleşip eşleşmediğine bakar |
| `Add-Aday` | Listeye öğe ekler; korumalı yolları ve var olmayan yolları eler |
| `Test-Korumali` | Bir yolun korumalı olup olmadığını kontrol eder |
| `ConvertFrom-Secim` | `1,3,5-7` gibi girdileri numara listesine çevirir |
| `Invoke-Menu` | Seçim, yöntem ve onay döngüsünü yönetir |
| `Remove-Aday` | Siler ve sonucu doğrular |

## Katkıda bulunma

Katkılar memnuniyetle karşılanır! Özellikle şunlar çok işe yarar:

- Yanlış alarm veren klasörler için **takma ad** eklemeleri
- Yeni **önbellek kuralları** (Rust, Go, .NET, Unity, Unreal...)
- AMD / Intel sürücü paketi desteği

Pull request göndermeden önce:

1. Yeni bir kural eklediysen, kuralın **korumalı yolları** etkilemediğinden emin ol.
2. Emin olmadığın her şeyi `KONTROL` olarak işaretle. `GUVENLI` etiketi yalnızca **kendini yeniden oluşturan** dosyalar içindir.
3. Testleri çalıştır ve hepsinin geçtiğinden emin ol:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\Test-DiskTemizleyici.ps1
   ```
4. `.ps1` dosyalarını **UTF-8 BOM** ile kaydet.

## Sorumluluk reddi

Bu araç, bilgisayarındaki dosyaları **senin onayınla** siler. Her öğe için açıklama ve risk etiketi sunulsa da hangi dosyanın gerçekten gereksiz olduğuna dair son karar sana aittir. Önemli verilerinin yedeğini almanı, emin olmadığın öğelerde **Geri Dönüşüm Kutusu** seçeneğini kullanmanı öneririz. Yazılım "olduğu gibi" sunulmaktadır ve kullanımından doğabilecek veri kayıplarından geliştiriciler sorumlu tutulamaz.

## Lisans

[MIT](LICENSE) © 2026 GeneralBuSa
