# L1 Boot Satranç — 512 baytlık x86 boot sektöründe FideLite L1 kurallarıyla satranç

> **Geliştirme kaydı (Türkçe).** Proje 19.11.2026'da **FullChess** adıyla yeniden düzenlendi; güncel
> kullanım bilgisi İngilizce `README.md`'de. Bu kayıt eski adları kullanır. Eşleme:
>
> | Bu kayıtta | FullChess reposunda |
> |---|---|
> | `src/l1yeni.asm`, `src/l1bot.asm` | `src/fullchess.asm`, `src/fullchess-cpu.asm` |
> | `derle.sh`, `regresyon.sh`, `TEST_SONUCLARI.txt` | `build.sh`, `test.sh`, `TEST_RESULTS.txt` |
> | `arac/`, `notlar/` | `tools/`, `docs/notes-tr/` |
> | `ii_sonuc_50_donme` (ana) | `bin/fullchess.bin/.img`, `bin/fchess.com` |
> | `bot_light_ply1` (ana) | `bin/fullchess-cpu.bin/.img`, `bin/fcvscpu.com` |
> | `ii_sonuc`, `ii_sonuc_50`, `ii_sonuc_donme` | `bin/extras/2p`, `2p50`, `2pflip` |
> | `ii_light`, `ii_light_redraw` | `bin/extras/2plight`, `2plightr` |
> | `bot_light_ply2`, `_ply2or`, `_ply3`, `_ply3or`, `_ply4`, `_ply4or` | `bin/extras/cpu2`, `cpu2or`, `cpu3`, `cpu3or`, `cpu4`, `cpu4or` |
> | `botfuzz.py` çıktısı `bot-spin-sonu` | `bot-spun` |
>
> **Yayından sonra düzeltilen hata (19.11.2026).** İki kişilik sürümlerde terfi tuşu yalnız Enter ve 1–4
> için tanımlıydı. Diğer tuşlar piyonu piyon bırakıyor, siliyor ya da geçersiz bir koda çeviriyordu
> (ör. `Q` → kale, boşluk → piyon yok olur); bu, FIDE 3.7'ye aykırı bir hamleydi. Düzeltme: 5. tuş artık
> `key` ile okunuyor (AL = tuş & 15, yankılı) ve `imul ax,ax,0x4b; or al,0x9f; aam 7` ile eşleniyor.
> `or al,0x9f` her baytı 9F/BF/DF/FF'den birine çevirir, `aam 7` bunları at/kale/vezir/file → **her tuş
> geçerli bir taş** (`q`/`Q` vezir, `n`/`N` at). Bu değişiklik +1 bayt; `FRONT=0xFF` ve doldurmada
> `jz/mov` yerine `neg al; salc` ile −1 bayt kazanıldı → hiçbir sürümün boyutu değişmedi (ana sürüm yine
> 510). 6 bayta kadar toplam eşleme yok (16 değer üzerinde, bayrak komutları dahil kapsamlı arama; ham tuş
> kodunda 5 bayta kadar yok). Bot sürümleri etkilenmedi: oradaki `inc ax; and al,3; add al,2` zaten her
> tuşu geçerli bir taşa çeviriyor. Yeni test: `tools/promokeys.py` (129 tuş kodu × her iki kişilik sürüm).
> Ders: hedefli testler yalnız belgelenen girişleri denedi; "her olası girdi" testi ayrıca gerekir.
>
> **Harfli terfi ve küçültme turu (25.11.2026).** Terfi arayüzü değişti: 5. tuş **N at, R kale, B fil**
> (büyük/küçük fark etmez), **başka her tuş vezir**. Boot sürümleri BIOS tarama kodunu okur (fiziksel
> tuş; Shift/Ctrl ile de, ör. Ctrl+B fil), DOS sürümleri harfi (`or al,0x20` ile). Bot, insanın son
> 5. tuşunun taşına terfi eder (eski kural). İlk hâli (5. tuş `key` ile ham, `or 0x20`, tablo + bekçi
> taraması) ana sürümü 524 B'a çıkardı; aşağıdaki küçültmelerle **492 B** (18 B boş). Alfabe ve 0x88
> tahta değişmedi; kazanç algoritma ve yerleşimden:
>
> | Teknik | Ana sürümde | Uygulandığı yer |
> |---|---|---|
> | Terfi tablosu açılış kodunun baytlarında: `mov cx,0x3013; cld; xor ax,ax` = `B9 [13 30 FC 31] C0`; ptab = start+1 (LO = 1: eşleşmede DI'nin alt baytı doğrudan taş kodu), bekçi = C0 (her tuşla ezilir), CX = dolgu sayısı | −4 | tüm boot sürümleri; bot: `B9 [13 30 31] C0`, `xor al,1` (Q4 ortada olduğu için 3 girişli tablo + xor dönüşümü) |
> | Terfi araması `try` içinde; `key` 5. tuşun kodunu bekçiye yazar (`promo` değişkeni yok) | −1 | iki kişilik; bot (bekçiyi ana döngü yazar) |
> | Girilen hamle yığının dibinde: `xor sp,sp; call key2; push di; call key2; push di` (`inp` = 0xFFFC) | −5 | iki kişilik |
> | `key2`'den `xchg si,di` çıktı (kareler hemen saklanıyor) | −2 | hepsi (bot: `mov [inp+2],di` / `mov [inp],di`) |
> | Tutma çıkışı: `try`'ın başı `main`'in hemen önünde, eşleşme `main`'e düşer; `sub sp,-18; dec cx; ret` ve `jc main` yok (açılış `jmp short main` ile atlar) | −4 | iki kişilik; bot: `jmp main` + `main`'de `xor sp,sp` |
> | Yedek döngüsü `movsw; inc cl; jnz` (pusha/popa yok; 255-256 word, CL'yi kendisi 0'lar → tutma çıkışında `dec cx` yok); kaynak işaretçisi çizim sonundaki SI = 0x8000 | −4 | iki kişilik; bot ply1–2 |
> | Ekran: çerçeve hücresi `cmp al,0x0d` yerine `add al,[di]`'nin taşmasından (0x0E+0xFF) | −2 | hepsi |
> | 50 hamle: `adc al,0xff; salc; inc [hm]; or [hm],al` (sıfırlama dalı yok); sayaç ledger+0 → ana döngüde `cmp byte [si],X` | −3 | FIFTY sürümleri |
> | `try` içinde SI serbest: `mov si,tbase` → enp/hm `[si]`, `[si+8]` | −3 | hepsi |
> | Geçerken almada `mov [bx],cl` (try'da CL = 0) | −1 | iki kişilik; bot ply1–2 |
> | Üreteçte yön işaretçisi doğrudan BX (adımda `mov bl,dl` yok; rok BX'i push/pop ile korur) | −2 | hepsi |
> | Şah alınınca `cmp al,8` (CF=1, ZF=0) → üreteçte `try` sonrası `jc cont` yok | −1 | hepsi |
>
> Boyutlar (boot / .COM): fullchess 492/476, 2p 466/450, 2p50 481/465, 2pflip 477/461, 2plight 444/436,
> 2plightr 444/436; fullchess-cpu 480/463, cpu2 488/471, cpu2or 484/467, cpu3or **510**/496 (harfli terfiyle
> yeniden sığdı), cpu3 (514)/500, cpu4or –/513, cpu4 –/517.
>
> Bu turda bulunan hatalar: (1) yerleşim değişince LIGHT sürümlerinde yön tabloları 256 baytlık sayfa
> sınırını aştı (TP `chars`'ın sayfasıydı; ayrıca `mov bl,LO(offsets-4)` + `xlatb` sayfa başında taşar).
> Düzeltme: TP = `offsets`'in sayfası; boot'ta `offsets-4..pawnb` tek sayfada değilse derleme hata verir,
> DOS'ta gerekirse dolgu eklenir. (2) Test kancası: Unicorn'da çalışma sırasında eklenen kod kancaları
> önceden çevrilmiş bloklarda tetiklenmez; teşhis kancaları `emu_start`'tan önce kurulmalı.
> Kazandırmayanlar: alfabe (kısıtlar 4 dizilime kilitliyor; iki kişilik alfabede 3 girişli tablo dönüşümü
> yok), ekran tablosunu açılış koduna gömmek (baytlar boş komut olarak kalıyor, kazanç 0), tabloyu 0x101'e
> hizalamak (yerleşim tutmadı; açılış kodu çözümü daha iyi). Testler: `run16.py` int 16h'de AH = ABD düzeni
> tarama kodu; `promokeys.py` boot için tarama kodu, DOS için harf kuralı; yeni `botpromo.py` (botun tek
> hamlesi terfi olan konum, 10 tuş). Gerçek BIOS: QEMU + SeaBIOS'ta Shift+N, r, Shift+B, Enter doğrulandı.
>
> **Özgünleştirme turu (25.11.2026, akşam).** Atomchess, BootChess, LeanChess, AttoChess ve ChessLin
> kaynakları derlenip makine kodu karşılaştırıldı (adresler yok sayılarak). İlgisiz programlarla en uzun
> ortak bayt dizisi 3–4 bayt; Atomchess'le 16 bayttı ve iki kişilik ana sürümde en az 4 komutluk aynı
> diziler 78 bayt tutuyordu (tuş → kare, taş seçimi, piyon sınıflama, ekran tablosu). Bunlar kendi
> tekniklerimizle yeniden yazıldı:
>
> | Parça | Yeni yazım | Ana sürümde |
> |---|---|---|
> | Tuş → kare | `aad 0xF0`: AL = dosya − 16 × yatak; önceki tuş BL'de (boot) / terfi bekçisinde (DOS); `key2` = `call key` + düşerek ikinci tuş. Boot'ta yatak rakam tuşunun tarama kodundan (1 = 02 … 8 = 09) | boot 0, DOS −1 |
> | Ekran | `and al,0x67; aam 0x20` (AH renk, AL tür) → düz harf tablosu `.PRBKNQ` → `aad 0x20` (renk küçük harf biti olarak geri); çerçeve işaret bitiyle (`jns`), CR/LF açıkça; tablonun 8. baytı arkasındaki bayttan (boot: initial[0] 0x82, DOS: 'r') | +1 |
> | Piyon sınıflama | Yön baytından: tek = çapraz, ±32 = çift adım; piyonluk `test byte [si],6` | +3 |
> | Taş seçimi | Taş başına tanım baytı `28 × yön sayısı + liste yeri`; `xlatb` + `aam 28` → AH sayaç, AL yer; siyah piyon tahtada `0x29` (işaret biti 0x08), kendi tanımı (indeks 8; 6–7 boş) | −3 |
> | Adım | Hedef DX'te (DH tahta sayfası, DL kare): `add dl,[bx]; mov di,dx`; sayaç AH'de (`dec ah`), `try` çift adımı `dec ah` ile tanır; rok kaleyi ararken `pusha`/`popa` (AH korunur) | 0 |
> | DOS dolgu sayısı | `mov cx,di` (adres = sayaç) yerine `mov ch,2` | 0 |
>
> Sonuç (boot / .COM): fullchess **493**/476, 2p 467/450, 2p50 482/465, 2pflip 478/461, 2plight 445/431,
> 2plightr 445/431 (ilk hâl 492/476 …; arada +4 sürümü 496/479 idi, taş seçimi onu 3 bayt geri aldı).
> Atomchess'le en az 4 komutluk aynı diziler 78 → **35 bayt**; kalan üçü genel kod (BIOS tuş okuma +
> yankı, kurulumun başı `mov si / mov di / mov cl,8 / lodsb`, satır sonu basma). En uzun birebir dizi
> 12 bayt (BIOS çağrısı).
>
> Hâlâ Atomchess'ten gelen fikir/iskelet (README Credits'te anılıyor): tahta sayfası 0x7F00 ve döngülerin
> 0x8000'de işaret bitiyle bitmesi, çerçeve karesinin yeni satır başlatması (`add si,7`), kurulum
> döngüsünün biçimi (renkler ters), piyon yönlerinin sırası (yakalama, yakalama, ileri, çift). Bot
> sürümü (`fullchess-cpu.asm`) henüz eski çekirdekte: taş seçimi, adım, piyon, tuş → kare, harf tablosu
> Atomchess türevi; sıradaki iş. Önceki teknik: ChessLin (Poudade, 2016) koordinatı `sub ax,3161h; aad 16`
> ile çeviriyor; bizim `aad 0xF0` ondan bağımsız bulundu ve README'de anılıyor.
>
> Davranış farkı: boot'ta yatak tuşu ana klavyedeki 1–8 (sayısal tuş takımı çalışmaz; AZERTY'de üst sıra
> Shift'siz çalışır); DOS'ta dosya tuşu harf olmalı (eskiden `5254` = `e2e4` idi). Bot değişmedi.
>
> Taş seçiminde denenip bırakılanlar: siyah piyona ayrı tür kodu 7 (kayan taş bit testiyle çakışıyor:
> 1–7'de her bit 4 kodda); iki tanım tablosu 32 bayt arayla ve `or al,ch` (+7); sonlandırıcılı ya da
> 8'e hizalı biten listeler (+6–9 ya da dolgu); renk bitini 0x80'e taşıyıp yönün işaretiyle denetim
> (8 yönlü dört taşa üç boş kod); tanım tablosunun 2 boş baytını yön tablosuyla örtüştürmek (kazanç 0).
>
> "Alınırsa kısaltır" ölçümleri (README'deki tablo): Atomchess'in piyon sınıflaması (liste yeri +
> `inc`/`cmp`/`dec`, sayaç AH'de olduğu için `inc al`) **−2 B** (491, testler geçti); Atomchess'in
> harf−kod tablosu eski alfabede −1, siyah piyon işaretiyle ek kod ister; taş seçimi ve `imul`/`lea`
> kısaltmıyor (+3, 0/+1). LeanChess/AttoChess'in tablosuz harf (`add`, fil `O`) ve yarım yön tablosu
> (`neg`) ölçülmedi. ChessLin'in 32 bit sıra sabiti 386 ister. BootChess ve Reloaded'da kısaltan bir şey
> bulunmadı; Super Micro Chess'in assembly kaynağı yayımlanmamış.
>
> Testler: `test.sh` tam tur 59 satır, **0 hata** (iki kişilik rastgele oyunların hamle sayıları öncekiyle
> birebir aynı: davranış değişmedi); QEMU + SeaBIOS'ta rok ve geçerken alma oynandı, siyah piyon `p`.

> Deneysel bir eğlence projesi. Hedef: FideLite L1 kurallarının **hiçbirini atmadan** (yasallık,
> rok, geçerken alma, seçmeli terfi, mat/pat) insan-insan ve insan-bilgisayar satrancını tek bir
> 512 baytlık x86 boot sektörüne sığdırmak; aynı kodun DOS .COM sürümlerini de üretmek.
> Bu dosya projenin tek başına yeten kaydıdır: sürümler, nasıl üretildikleri, mimari, ölçümler,
> kazandıran/kazandırmayan her deneme, hatalar, test yöntemi ve açık işler.
>
> Kayıt tarihi: 16 Kasım 2026; yayın hazırlığı güncellemesi: 19 Kasım 2026.
> Kaynak kurallar: FideLite (https://fidelite.art, https://github.com/cuneytinann/FideLite).

---

## 0. Durum ve karar bekleyenler

Kararlaştırılanlar (19.11.2026):
- **Ana sürümler:** insan-insan **`ii_sonuc_50_donme`** (510 B: tüm L1 kuralları + mat/pat gösterimi
  + 50 hamle + tahta dönme), insan-bot **`bot_light_ply1`** (484 B). Diğerleri "ekstra" sürüm olarak yayımlanır.
  (25.11: harfli terfiyle 492 B ve 480 B; bkz. en üstteki not.)
- **Sonuçlu bot sürümleri yayımlanmaz** (`bot_sonuc_ply1` 504 B, `bot_sonuc_ply2or` 508 B). Kodları
  `l1yeni.asm`'den de çıkarıldı (bkz. 2.2 ve 5).
- Girişin 5 tuşluk yapısı ve Backspace'in çalışmadığı kullanım notuna eklendi (bölüm 1.2).
- Yayından önce düzeltilenler: kaynak başlıkları, araçlardaki sabit yollar, iddia taslağındaki tutarsızlık,
  karşılaştırma tablosu kaynaklardan yeniden doğrulandı (bölüm 12).

Karar bekleyenler:
1. **Repo adı** — henüz verilmedi. GitHub'a ayrı repo olarak yüklenecek.
2. **Rekor iddiası metni** — taslak ve doğrulanmış karşılaştırma bölüm 12'de.
3. Lisans, README'nin İngilizce sürümü, gerçek donanım (disket/USB) testi.
4. (İsteğe bağlı) Ana/ekstra ayrımı `bin/` içinde klasörle de yapılsın mı? Şu an yalnız README'de.

Kapanan defterler (tekrar açılmayacak):
- **Bot için "kural ve hesaplama iç içe, baştan yazım"**: ply1/ply2'de bayt kazandırmadı
  (bkz. 9.3). ply3 boot denemesi de bırakıldı (max hâli 513 B; OR hâli 509 B ile sığıyor ama ana
  hedef değil).
- **Eksen 1 (tahta geometrisi), Eksen 2 (alfabe), Eksen 3 (sıfırdan yazım)**: tamamlandı.

---

## 1. Kurallar ve arayüz

### 1.1 Kural kümesi (FideLite L1)
Her sürümde **tamamı** var:
- Tüm taşların temel hareketleri, piyonun çift adımı.
- **Yasallık**: kendi şahını tehdit altında bırakan / şaha giren hamle reddedilir (insan için de, bot için de).
- **Rok** (kısa ve uzun), tüm koşullarıyla: şah ve kale hiç oynamamış, arası boş, şah şu an şahta değil,
  geçtiği kare ve vardığı kare tehdit altında değil. Kale yenip başka kale aynı kareye gelirse rok yok.
- **Geçerken alma** (yalnız hemen sonraki hamlede).
- **Terfi, seçmeli**: vezir / at / fil / kale.
- **Mat ve pat**: sonuçlu sürümlerde gösterilir; "light" sürümlerde oyun kendiliğinden donar
  (hiçbir hamle kabul edilmez) — FideLite'ın L1_light'ı gibi.

Ek seçenekler (FideLite L1'in ötesi): 50 hamle kuralı (otomatik), tahtanın sıradaki tarafa göre dönmesi.
Yok: üç tekrar, yetersiz materyal, beraberlik teklifi, terk.

### 1.2 Arayüz (tüm sürümlerde aynı, "donduruldu")
- Giriş: `dosya sıra dosya sıra` + **Enter**, ör. `e2e4⏎`. Rok şahın hamlesiyle girilir: `e1g1`, `e1c1`.
- Terfi (25.11'den beri): Enter yerine terfi harfi: **N at, R kale, B fil** (büyük/küçük fark etmez), başka her
  tuş vezir. Ör. `e7e8` + `n` = ata terfi. Boot: tarama kodu (fiziksel tuş), DOS: harf. (Eskiden 1 vezir,
  2 at, 3 fil, 4 kale.)
- Çıktı: 8 satır tahta. `.` boş, `PNBRQK` beyaz, `pnbrqk` siyah. Üst satır 8. sıra (dönen sürümde
  sıra siyahtaysa tahta 180° döner; giriş koordinatları yine mutlaktır).
- Oyun sonu (sonuçlu sürümler): `#` mat, `=` pat (50 hamle sürümünde 50 hamle beraberliği de `=`).
- Yasa dışı giriş sessizce reddedilir; tekrar yazılır. Tahtanın altındaki boş satırlar serbest.
- Bot sürümlerinde insan beyaz, bot siyah; bot cevabını hemen oynar. Bot terfi ederse, insanın
  **son girişindeki 5. tuşun** taşını alır: normalde Enter → vezir; insan son hamlesinde `2` bastıysa
  bot da ata terfi eder.

**Girişte satır düzenleme yok — Backspace çalışmaz.**
- Her hamle denemesi tam **5 tuş**tur: 4 koordinat tuşu + Enter (ya da terfi tuşu). Program "yazıldı /
  silindi" tutmaz, yalnız tuşları sayar.
- Her tuşun yalnız alt 4 biti okunur: `a` = `A` = `1` … `h` = `H` = `8`. Yani `e2e4⏎`, `5254⏎` ve
  `ebe4⏎` aynı hamledir. Backspace'in kodu 0x08'dir; program onu `h` ya da `8` gibi okur.
- Ekranda: ilk 4 tuş yazılır, 5. tuş yazılmaz. BIOS'ta Backspace imleci bir sola alır ama karakteri
  silmez. Sayım kaymışken Enter bir koordinat yerine denk gelirse imleç satır başına döner.
  Reddedilen denemeden sonra yeni satıra geçilmez (`ii_light_redraw` hariç), yeni yazılanlar aynı satıra düşer.
- **Hata yaparsanız:** Backspace'e basmayın. Denemeyi Enter'larla 5 tuşa tamamlayın (reddedilir), sonra
  hamleyi baştan yazın. Backspace'e bastıysanız, o da 5 tuştan biri sayılır.
- **Sayım kaydıysa:** hamleyi yazın; tahta yeniden çizilmezse bir Enter fazladan basıp tekrar deneyin.
  Her fazladan Enter sayımı bir tuş kaydırır; en çok 4 ek denemede hizalanır. Nadiren, kaymış bir
  giriş tesadüfen yasal bir hamle oluşturup oynanabilir.
- `ii_light_redraw` her 5 tuştan sonra tahtayı yeniden çizer; denemenin bittiği yer orada görünür.
- Bu, bayt kazanmak için bilinçli bir seçimdir; satır düzenleme birkaç bayta mal olur (ölçülmedi).
  Emülatörde doğrulandı (19.11): `e2x⌫e4⏎` oynanmaz; `e2x⌫⏎` + `e2e4⏎` oynanır; `5254⏎` ve `ebe4⏎` e2e4'tür.

---

## 2. Sürüm envanteri (her özellik kümesinin en küçüğü)

Boyutlar **kod baytı**dır (boot: dolgu ve 0x55AA imzası hariç; sektörde kullanılabilir alan 510 B).
.COM boyutu dosya boyutudur. Hepsi `derle.sh` ile yeniden üretilir.

### 2.1 İnsan vs insan — kaynak `src/l1yeni.asm`

| Dosya adı | Bayraklar | boot | .COM | 19.11 (boot/.COM) | Özellik |
|---|---|---|---|---|---|
| **`ii_sonuc_50_donme`** (ana sürüm) | `-DFIFTY -DFLIP` | **493** | 476 | 510/488 | Tüm L1 + `#`/`=` + 50 hamle + tahta dönme |
| `ii_sonuc` | — | **467** | 450 | 479/457 | Tüm L1 kuralları + `#`/`=` |
| `ii_sonuc_50` | `-DFIFTY` | 482 | 465 | 499/477 | + 50 hamle (100 yarım hamle) otomatik beraberlik |
| `ii_sonuc_donme` | `-DFLIP` | 478 | 461 | 490/468 | + sıra siyahtaysa tahta 180° döner |
| `ii_light` | `-DLIGHT` | **445** | 431 | 457/437 | Tüm L1 kuralları, oyun sonu göstergesi yok (oyun donar) |
| `ii_light_redraw` | `-DLIGHT -DREDRAW` | 445 | 431 | 455/435 | Aynı; her girişten sonra tahta yeniden çizilir (arayüz farkı) |

Boyutlar 25.11 akşamı itibarıyla (harfli terfi + özgünleştirme turu); son sütun 19.11'deki (1–4 tuşlu) hâli.

`-DPLIES=150`: 50 yerine FideLite L2'deki gibi otomatik **75 hamle** (aynı bayt; hazır derlenmiş sürümü yok).
Sektörde boş kalan (25.11): ana sürüm 18 B, `ii_sonuc` 44 B, `ii_light` 66 B.

### 2.2 İnsan (beyaz) vs bot (siyah) — kaynak `src/l1bot.asm`, yalnız materyal, hepsi "light"

| Dosya adı | Bayraklar | boot | .COM | 19.11 (boot/.COM) | Arama |
|---|---|---|---|---|---|
| **`bot_light_ply1`** (ana sürüm) | `-DPLY=1 -DSPIN` | **480** | 463 | 484/464 | aldığı taşın değeri |
| `bot_light_ply2or` | `-DPLY=2 -DOR2 -DSPIN` | 484 | 467 | 488/468 | aldığı − rakibin tehditlerinin OR'u (yaklaşık) |
| `bot_light_ply2` | `-DPLY=2 -DSPIN` | 488 | 471 | 492/472 | aldığı − rakibin en iyi alması (gerçek max) |
| `bot_light_ply3or` | `-DPLY=3 -DOR2 -DSPIN` | 510 | 496 | 509/489 | 3 yarım hamle (OR yaprak) |
| `bot_light_ply3` | `-DPLY=3 -DSPIN` | (514, sığmaz) | 500 | (513)/493 | 3 yarım hamle |
| `bot_light_ply4or` | `-DPLY=4 -DOR2 -DSPIN` | sığmaz | 513 | –/506 | 4 yarım hamle (OR yaprak) |
| `bot_light_ply4` | `-DPLY=4 -DSPIN` | sığmaz | 517 | –/513 | 4 yarım hamle |

Bot .COM'ları biraz büyüdü: DOS'ta terfi tablosu ayrı durur ve `xor` dönüşümü için 8'e göre hizalanır.

Notlar:
- "Light": oyun sonu gösterilmez. Bot hamle bulamazsa (mat/pat) program boş döngüde döner (eski `jmp $` gibi);
  insan hamle bulamazsa giriş bekler, hiçbir giriş kabul edilmez.
- Bot terfisi: insanın son girişindeki 5. tuş (bkz. 1.2). 25.11'den beri `tools/botpromo.py` ile otomatik
  sınanıyor (botun tek hamlesinin terfi olduğu konum; n/N/r/R/b/B/Enter/q/x/2 → at/at/kale/kale/fil/fil/vezir...).
- ply3/ply4: insan hamlesinin yasallığı ply3'te tam derinlikte (yavaş ama doğru), ply4'te yalnız
  yasallık derinliğinde (hızlı) kontrol edilir.
- ply ≥ 3 zayıflığı: rakibin hiç yasal cevabı yoksa (mat ya da pat) büyük kazanç sayılır → bot
  patı da kovalayabilir (ayırt etmek için şah kontrolü gerekir; "yalnız materyal" kapsamı dışında).
- Bot ağırlıkları: piyon 1, at 2, fil 2, kale 3, vezir 4 (tablosuz `aam 5; aad 2`).
- **Yayından çıkarılanlar (19.11):** sonuçlu botlar `bot_sonuc_ply1` (boot 504 / .COM 482) ve
  `bot_sonuc_ply2or` (508 / 486), eskiden `l1yeni.asm -DBOT [-DGREEDY]` ile üretiliyordu. Kodları ve
  ikili dosyaları 16.11 arşivinde duruyor.

### 2.3 Dosya biçimleri
- `*.bin`: 512 baytlık boot sektörü (sonu `55 AA`).
- `*.img`: aynı sektörün 1.44 MB disket görüntüsü (emülatörde doğrudan açılır).
- `*.com`: DOS .COM (org 0x100). Boot sürümünün BIOS/segment kısımları çıkarılmış hâli:
  ekran `int 29h`, klavye `int 21h/08h`, oyun sonunda `ret` (sonuçlu sürümlerde).

---

## 3. Derleme ve çalıştırma

```
nasm -f bin [-Dboot] <bayraklar> src/l1yeni.asm -o x.bin    # -Dboot yoksa .COM üretir
bash derle.sh                                             # tüm envanter (.bin/.img/.com) + boyut tablosu
bash regresyon.sh                                         # tüm sürümlerin son test turu
KIND=bin bash regresyon.sh                                # yalnız boot (KIND=com: yalnız .COM)
```
Gereksinimler: derleme için `nasm`; test için `python3` ve `pip install unicorn chess`;
isteğe bağlı `qemu-system-i386` + `pillow` (`arac/qboot.py`).

Çalıştırma:
- **Tarayıcı (kurulum yok):** v86 — https://copy.sh/v86/ → "Floppy disk image" alanına `.img` seç → Start.
- **QEMU:** `qemu-system-i386 -fda ii_sonuc_50_donme.img` (ya da `-drive format=raw,file=x.img`).
- **DOSBox:** `.com` dosyasını doğrudan çalıştır; ya da DOSBox içinde `boot x.img`.
- **Gerçek donanım:** `.bin`'i disket/USB'nin ilk sektörüne yaz (dd / Rawrite). (Henüz denenmedi.)
- Hamle girerken Backspace kullanmayın (bkz. 1.2).

---

## 4. Mimari (tüm sürümlerin ortak çekirdeği)

Atomchess (Óscar Toledo) tarzı üreteç temel alındı, kural tarafı baştan tasarlandı.

### 4.1 Bellek ve tahta
- **Tahta**: 0x7F00 sayfası, 16 sütun genişlik. Satır 0–7 × sütun 0–7 kareler (üst satır = 8. sıra),
  sütun 8–15 ve satır 8–15 "çerçeve". Adım ekleme yalnız düşük baytta yapılır (`xchg ax,di; add al,[bx];
  xchg ax,di`): dikey taşma sayfa içinde sarar, çerçeve kendiliğinden dolgu olur.
- **ledger** = tahtanın önündeki 128 bayt (0x7E80): geçerken alma karesi `enp` (+8), 50 hamle sayacı `hm` (+10).
  Yedeklenen/geri konan bölgede olduğu için yasa dışı denemelerde kendiliğinden geri alınır.
- **save** = 0x8000: 256 baytlık konum yedeği. Yedek alındığında ledger'daki çerçeve baytları
  botta `best` (bot bekçisi = FRONT = −121) gibi alanları kendiliğinden başlatır; geri koyma 250 bayt
  (125 word) olduğu için +0xFA ve sonrası (best/inp/promo) korunur.
- Başlangıçta `fill` 0x7E80'den itibaren 0x7E80 bayt doldurur: `(adres & 0x88) == 0` → 0, değilse FRONT.

### 4.2 Taş kodlaması
- Tür alt 3 bitte, renk biti `BLACK = 0x20` (ekranda küçük harf = +0x20), `UNMOVED = 0x80` yalnız
  hiç oynamamış şah/kalelerde (oynayınca `and al,0x7f` ile silinir; ekranda `& 0x7f` ile görünmez).
- Boş = 0. Çerçeve = FRONT (alt 3 biti 7 → ekranda satır sonu).
- **İnsan alfabesi A2:** P1 K(kale)2 F3 Ş4 A5 V6, FRONT 0x8F. Kayan taşlar (kale, fil, vezir) bit1'de
  → "kayar mı" testi `test byte [si],2`. Alma testi `xor al,0x23` (şah → 7).
  Terfi tuşu eşlemesi `inc ax; xor al,0x83; aam 9` (kaba kuvvetle bulundu; 19.11'de `imul/or/aam`,
  25.11'den beri harf tablosu: en üstteki nota bakın).
- **Bot alfabesi:** P1 F2 K3 V4 A5 Ş6, FRONT 0x87 (negatif: bot bekçisi). Ağırlık `aam 5; aad 2`.
  Alma testi `sub al,BLACK; cmp al,KING` (şah en büyük kod). Terfi (19.11) `inc ax; and al,3; add al,2`;
  25.11'den beri tarama kodu tablosu `[13 30 31]` + `xor al,1` (Q4 ortada, sırası 3 kale, 2 fil, 5 at, 4 vezir).

### 4.3 Hamle üretimi (`play`)
- `si` 0x7F00'den taranır, `inc si; jns sq` 0x8000'de durur.
- Kendi taşı mı: `and al,0x7f; xor al,ch; dec ax; cmp al,6; jnc`.
- Beyaz piyon tespiti `cmp byte [si],PAWN+1; sbb al,0xfb`; yön sayısı hilesi `mov ah,0x0c; and ah,al`;
  yön tablosu `xlatb` ile (tablolar: rookd, bishd, disp(at), pawnw, pawnb; şah = rookd+bishd, tek adım).
- Hedef sınıflandırma: boş / rakip taş / kendi taşı ya da çerçeve / **rakip şah** (→ `stc; ret`:
  bir önceki hamle yasa dışı).
- Piyon: çift adım satır paritesiyle (`test si,0x60; jpe`), geçerken alma `di == [enp]`,
  atlanan kare `xor bl,0x10`, terfi satırı `lea dx,[di+0x10]; test dl,0x60`.

### 4.4 Yasallık, oynama, mat/pat
- **Kopyala-oyna:** her taramadan önce konum `save`'e yedeklenir; `try` hamleyi uygular, rakibin
  cevaplarını tarar (`rply`: tarafı çevir, `cl=1` yanıt katmanı), şah alınabiliyorsa yasa dışı;
  sonra konumu yedekten geri koyar.
- **Girilen hamle**: yasal adaylar arasında `inp` ile karşılaştırılır; eşleşen tutulur
  (19.11: `sub sp,byte -18; dec cx; ret` ile ana döngüye dönülür, CF=1. 25.11'den beri iki kişilikte `inp`
  yığının dibinde (0xFFFC, girdi `push` eder) ve `try`'ın başı `main`'in hemen önünde: eşleşme doğrudan
  `main`'e düşer, yığın bir sonraki girdide `xor sp,sp` ile sıfırlanır; botta `jmp main`.)
- **Mat/pat (sonuçlu):** yasal hamle sayacı (pusha çerçevesindeki BP: `inc word [si+4]`); sıfırsa
  `over`: mevcut konumda rakip şahımızı alabiliyor mu → `#`, değilse `=`
  (`salc; and al,'#'-'='; add al,'='`).
- **Rok:** ayrı üretici yok. Şahın ilk adımı (e1→f1) yasal bulunursa ve şah UNMOVED ise devam kodu:
  aynı yönde kendi UNMOVED kalesine kadar boş kareler, "şu an şahta mı" yoklaması (`pusha; call rply; popa`),
  kale geçilen kareye konur ve şahın ikinci adımı (e1→g1) normal `try` ile yasallık için denenir.
- **50 hamle:** sayaç ledger'da, piyon hamlesinde/almada sıfırlanır (`stc` + `xchg [di],al; adc al,0`),
  mat/pat kontrolünden sonra eşik eşitliğiyle `=` (eşitlikte CF=0 → `salc` '='). 25.11'den beri
  `adc al,0xff; salc; inc [hm]; or [hm],al` (dalsız) ve sayaç ledger+0'da: ana döngüde `cmp byte [si],X`.
- **Tahta dönme:** okuma adresine `XOR 0x77` (kare (r,c)→(7−r,7−c); çerçeve çerçevede kalır);
  maske `mov al,ch; aam 0x20; aad 0x77; xchg dx,ax`.

### 4.5 Ekran ve giriş
- Ekran: karakter = `chars[c & 7] + c`, sonra `& 0x7f`. Çerçeve hücresi CR üretir → 7 hücre atla, LF.
  25.11'den beri çerçeve `add`'in taşmasından tanınır (0x0E+0xFF taşar, hiçbir taş taşmaz): `cmp al,0x0d` yok.
- Giriş (`key2/key`): tuş & 0x0F, `imul bp/bx,ax,-16; lea di,[bx+di+board+127]` ile kareye çevrilir.
  Doğrulama ya da düzenleme yok: her deneme sabit 5 tuş (bkz. 1.2). İlk 4 tuş BIOS teletype ile yankılanır.
- Boot: `org 0x7C00`, `xor ax,ax; mov ds/es/ss,ax; mov sp,ax` (hasım başlangıç yazmaçlarına dayanıklı),
  ekran `int 10h/0Eh`, klavye `int 16h`, oyun sonu `jmp $`, `times 510-($-$$) db 0; dw 0xAA55`.

### 4.6 Bot (l1bot.asm)
- Yalnız "light" sürüm üretir (sonuç kodu yok).
- **İki geçiş:** 1. geçiş tüm yasal hamleleri puanlar, en iyisini `best/inp`'e kaydeder (puan > best);
  bot sırasıysa 2. geçiş aynı taramayı yapar, eşitlik kaydedilmez, `inp` ile eşleşen hamle oynanır.
  İnsan sırasında da 1. geçiş yapılır (best max olsun ki insanın hamlesi "kayıt" dalına düşmesin).
  Ana döngü (`SPIN`): `chk: call root; jc main; test ch,ch; jnz chk; giriş; jmp chk`.
- **Kural ve değerlendirme iç içe:** yasallık için zaten yapılan rakip cevap taraması aynı geçişte
  rakibin en değerli almasını da toplar (`cmp ax,bp; jle; mov bp,ax` ya da `or bp,ax`).
  Puan = `aldığım − bp`.
- **Terfi:** `try` terfi taşını tablo bekçisindeki koddan arar; bekçiyi yalnız insanın 5. tuşu yazar → bot da
  insanın son girişindeki terfi tuşunu kullanır (bkz. 1.2).
- **ply ≥ 3:** her "yapma" seviyesinin kendi yedek tamponu var: 0x6007 + (L−1)·0x100. Tampon başında
  `[best][inp]`, geri koyma +6'dan. Yaprak dışı seviyelerde BP = tampon adresi; adres pozitif ve alt 3
  biti 111 olduğu için koşulsuz max/or BP'yi bozmaz. `node:` = yedekle ve doğrudan `root`'a düş
  (ana döngü ve iç seviyeler ortak). ply3'te seviye ayrımı parite bayrağıyla (`inc cx; jpe` /
  `test cl,cl; jpe`), ply4'te `cmp cl,PLY`.

---

## 5. Tarihçe (özet)

1. **.COM ile başlangıç:** insan-insan, bot greedy (ply1) ve "2-ply" (OR) sürümleri; `l1.asm` tek kaynak.
   Boyutlar (A2'den önce): insan .COM 469.
2. **Boot'a taşıma** (BootChess/Atomchess gibi doğrudan açılsın): insan boot 491; bot boot 510 sınırına
   kural atmadan sığdırıldı.
3. **Eksen 1 — tahta geometrisi:** 16 genişlik en iyi çıktı (aşağıda).
4. **Eksen 2 — alfabe:** A2 alfabesi −5 → insan boot 486 / .COM 464.
5. **Eksen 3 — sıfırdan yazım (insan):** mimariler tartıldı, üretici mimarisi kaldı; yapı-içi −5 → 481.
6. **Light** (L1_light gibi): −22 → 459 (redraw ile 457).
7. **Rok yeniden yazımı:** −2 tüm sürümlerde → sonuçlu 479, light 457 (redraw 455).
8. **50 hamle (+20) / tahta dönme (+11):** ikisi birden 510 (tam dolu).
9. **Bot, kural ve hesap iç içe, sıfırdan (`l1bot.asm`):** ply1/ply2 kazanç yok (sonuç kodu
   çıkarmanın −20'si hariç); `SPIN` eski tek döngü daha küçük çıktı; ply3 550→509 (OR), ply4 .COM 513.
10. **Yayın hazırlığı (19.11):** ana sürümler seçildi; sonuçlu botlar yayından çıkarıldı. `l1yeni.asm`'den
    bot dalları, `l1bot.asm`'den hiç derlenmeyen dallar (insan alfabesi, sonuç kodu, FLIP/FIFTY/REDRAW)
    silindi; kaynak başlıkları yeniden yazıldı. Teslimdeki 33 dosya ve tüm bayrak kombinasyonları
    (l1bot 49, l1yeni 27) eskisiyle bayt bayt aynı. Araçlardaki sabit yollar kaldırıldı.

---

## 6. Ölçülen kazanımlar (neler kazandırdı)

| Değişiklik | Kazanç | Not |
|---|---|---|
| A2 alfabesi (kayan taşlar bit1'de, şah alma `xor 0x23`) | −5 | cont `test byte [si],2` |
| `rply`: `mov cl,1` → `inc cx` | −1 | cl her çağrıda 0 |
| `try`: `cmp dh,1; je` → `dec dh; jz` | −1 | dh sonra eziliyor |
| Terfi/giriş: `promo` hemen `inp`'in önünde, tek `stosb+stosw+stosw` | −1 | yalnız insan sürümü |
| Tutma çıkışı: `popa; pop ax; xor ch; stc; ret` → `sub sp,byte -18; dec cx; ret` | −2 | rply tarafı zaten çevirdi; SP<0xFFEE → CF=1 |
| Rok: AL'de `ŞAH\|U\|renk`, adım AH'de, kale `xor al,ŞAH^KALE` | −2 | ilk denemede bug (bkz. 10) |
| Light: sayaç + mat/pat + `over` kaldırıldı | −22 (boot) | L1_light ile aynı davranış |
| Light+REDRAW: girişten önceki boş tarama kalktı | −2 | arayüz farkı: reddedilende yeniden çizim |
| Bot `SPIN` tek döngü (yeni iki-dallı döngü yerine) | −8 | bot hamlesizse döner |
| ply3: BP = seviye tamponu + tampon başında best | −12, −20 | 550 → 538 → 518 (OR 514) |
| ply3: `node` yedekle-ve-tara ortak girişi, parite ile seviye ayrımı, `jc/cbw` silme | dahil | |
| ply3 `SPIN` | −5 | 509 (OR) sığdı |
| 25.11 harfli terfi turu (13 teknik, en üstteki nota bakın) | 524 → 492 | ana iki kişilik; bot 480 |
| 25.11 özgünleştirme turu (Atomchess türevi parçalar yeniden yazıldı; en üstteki nota bakın) | 492 → 493 | iki kişilik; bot henüz değil |

## 7. Ölçülen maliyetler (özellik ekleri)

| Özellik | Maliyet |
|---|---|
| Sonuç gösterimi (mat/pat) | +22 boot (+20 .COM) |
| 50 hamle | +20 |
| Tahta dönme | +11 |
| Bot ply1 (light, insan light'a göre) | +27 |
| ply1 → ply2 (OR) | +4 |
| ply1 → ply2 (gerçek max) | +8 |
| ply2 → ply3 (OR, SPIN) | +21 |
| ply3 → ply4 (.COM) | +20 |
| .COM → boot farkı | ≈ +20 (segment kurulumu 11 B, BIOS G/Ç) |

---

## 8. Eksenler: geometri ve alfabe sonuçları

**Geometri (A2 ile, insan boot):**
- 16 genişlik: 486 (taban, en iyi).
- 10×8 (tahta sayfa sonunda): 495 (+9) — dolgu `aam 10` (+6), geçerken alma/atlanan kare (+4),
  çift adım (+1), ekran (−2). Kuruldu ve doğrulandı (90 oyun).
- 11/12 genişlik: ~+9 (hesap). 10×12: ≥ 10×8. 8×8: +15…25 (hesap; yatay taşma her adımda kontrol,
  ekranda satır sayacı).

**Alfabe:**
- A2 = P1 K2 F3 Ş4 A5 V6: −5 (seçildi).
- A1 (ayrı "kayan" biti): terfi eşlemesi ≤6 B bulunamadı → en iyi −3, elendi.
- A2'nin diğer 3 dizilimi: terfi eşlemesi 6 B ya da yok.
- Tümleyen renk (siyah = ~beyaz): −2 (`not ch`) +4 (ekran) = +2, elendi.
- Bot için A2 kullanılamaz: alma dönüşümünde fil → 0 (boş kareyle karışır), bot ayrı alfabe kullanır.

---

## 9. Kazandırmayanlar / elenenler

### 9.1 Mimari (Eksen 3, hesap)
1. Doğrulayıcı V(i,f) (h·v / kareler): net ≈ +30 (tüm çiftler döngüsü, saldırı testi, şah bulma).
2. Tahtayı her hamlede çevirmek (hep beyaz oynar): net ≈ +30.
3. Hamle listesi + seçim: daha büyük. 4. Kopya tahta / segment: daha büyük.
5. Doğrudan VRAM'e yazmak: ES, öznitelik, imleç → daha büyük.
Sonuç: sıfırdan yazım aynı üretici mimarisine varıyor; kazanç yalnız yapı içinde.

### 9.2 Mikro denemeler
- Ekran çift/tek çerçeve hücreleriyle CR/LF (−5 iddiası): 16 genişlikte dolgu parite mantığı (+7–8) kazancı yiyor.
- `aam 16` ile tuş çevirme (−1): büyük harf dosya girişini bozar, arayüz değişir → alınmadı.
- FRONT=0xFF + dolguda `neg al; salc` (−1): insan sürümünde denenmedi; botta bekçi negatif büyük olmalı → olmaz.
- Terfi eşlemesinin 4 baytlık hâli (tarama kodu AH dahil kaba kuvvet): yok.
- ply3'te farklı tampon düzenleri (best sonda, geri koyma tamponun tamamı): ya kazanç yok ya da
  bayat best başlangıcı (geri koyma best'i ledger'a yazıp bir sonraki yedeğe taşır) → yanlış.

### 9.3 Bot: "kural ve hesap iç içe, baştan yazım"
- ply1/ply2: **kazandırmadı.** 504/508 → 492/496 düşüşün tamamı sonuç kodunu atmaktan (−20)
  (504/508 = eski sonuçlu botlar; artık yayımlanmıyor).
  Yeni iki-dallı döngü (bot donunca girişte beklesin), eski tek döngünün sonuç kodsuz hâlinden 8 B büyüktü
  → eski döngüye dönüldü (`SPIN`). "Yanıt taraması = yasallık + tehdit" fikri eski 2-ply botta zaten vardı (OR).
- Yeni olanlar: gerçek max (+4) ve ply3/ply4 (eski tasarımda yoktu).

---

## 10. Hatalar ve dersler

- **Yerleşim değişince sayfa sınırı (25.11).** Kod blokları yer değiştirince LIGHT sürümlerinde yön tabloları
  256 baytlık sayfa sınırını aştı; testler yakaladı (hedefli vakaların hepsi düştü). İki ayrı neden: TP `chars`'ın
  sayfasıydı (tablolar öbür sayfadaydı) ve `offsets` sayfa başına denk gelince `mov bl,LO(offsets-4)` + `xlatb`
  bir sonraki sayfaya taşıyor. Ders: üreteç tabloları için derleme zamanı denetimi (`offsets-4..pawnb` tek
  sayfa; boot'ta aşılırsa derleme hata verir, DOS'ta dolgu eklenir). Yalnız ana sürümü sınayan hızlı test
  yetmedi: her yerleşim değişikliğinden sonra bütün bayrak birleşimleri derlenip sınanmalı.
- **Teşhis kancası (25.11).** Unicorn'da çalışma sırasında eklenen kod kancaları önceden çevrilmiş bloklarda
  tetiklenmez (sanki kod hiç çalışmıyormuş gibi görünür). Kancalar `emu_start`'tan önce kurulmalı.
- **Testsiz kazanç yoktur.** Rok yeniden yazımı ilk hâliyle 22/22 hedefli testten 3'ünü düşürdü: ilk adım
  kontrolü `bx`'i kareye çevirdikten sonra `.r`'ye atlıyor, `bh=TP` (tablo sayfası) geri yüklenmiyordu;
  üreteç sonraki yönleri tahta sayfasından okudu (Rg1 reddedildi). Emülatörde kanca ile bulundu, `jne .no` ile düzeldi.
- **Bot, rokten sonra yasa dışı oynuyordu:** değer tablosu `xlatb`'si `bl`'i bozuyordu → `mov bl,dl`
  (sonra ağırlık `aam/aad`'a geçince gerek kalmadı).
- **TOUCH biti çakışması:** FRONT 0x87 ile TOUCH 0x80 → ledger hücreleri "oynamış" görünüyordu → 0x40;
  sonra tamamen UNMOVED (oynamamış) bitine geçildi (daha küçük).
- **Hakem hatası da olur:** bellek modu hakeminin `CODE` tablosu A2 ile tutarsızdı (şah/vezir 4↔6) → tüm vakalar
  "başarısız" göründü. Çözüm: alfabeden bağımsız **ekran hakemi** (`BOARDSRC=screen`). Her yeni hakem kipi için
  **ters kontrol** yapıldı (eski sürüme uygulayınca başarısız olmalı).
- **SP'ye dayalı hileler** çağrı derinliğinin sabitliğine dayanır (tutma çıkışında CF'yi SP üretir); boot'ta SP=0,
  .COM'da 0xFFFE başlangıcıyla ikisi de doğrulandı.
- **"Baştan yazım" her zaman küçültmez:** mimari zaten iyi tasarlandıysa kazanç ancak yapı içinde; botta tamamen sıfır.
- **Ölçüm betiği de yanılabilir:** boot kodu tam 510 olunca listede dolgu adresi yok → betik bunu ayrıca ele alıyor.
- Not'lardaki eski tahminler (ör. "ekran −5") farklı bir tabana göre hesaplanmış olabilir; her iddia yeniden ölçülmeli.
- **Kaynak temizliğinde ölçüt bayt eşitliğidir:** yayın hazırlığında ölü dallar elle değil, bilinen sembolleri
  çözen bir betikle silindi; doğrulama tüm bayrak kombinasyonlarında eski/yeni ikili dosyaların aynı olmasıydı.
- **Test konumu da yanılabilir:** bot terfisini denerken kurulan ilk konumda b8'e çıkan vezir/kale siyah şaha
  şah çekiyordu, bot almayı (doğru olarak) yapmadı. Konumun kendisi de denetlenmeli.

---

## 11. Test yöntemi ve araçlar (`arac/`)

Gereksinimler: `python3`, `pip install unicorn chess`, `nasm`; isteğe bağlı `qemu-system-i386` + `pillow`.
Araçlar birbirini kendi klasörlerinden bulur; herhangi bir klasörden çalıştırılabilir.

- `run16.py` — Unicorn tabanlı 16 bit emülatör: .COM (DOS int 21h/29h) ve boot (BIOS int 10h/16h) kipleri,
  `BOOTREGS=hostile` (rastgele başlangıç yazmaçları), `jmp $` (EB FE) yakalama, `MAXINSN` komut sınırı.
- `targeted.py` — hedefli vakalar (22; `FIFTY` ile 27): rok her koşulu, geçerken alma, tüm terfiler, mat/pat,
  şaha girme, kale yenip yerine gelen kale vb. Her adımdan sonra tahta python-chess ile karşılaştırılır,
  yasal/yasa dışı her deneme ayrıca sınanır.
- `fuzz.py` — rastgele insan-insan oyunları (`--bias` almaya/özel hamlelere yanlı), her girişte tahta karşılaştırması,
  yasa dışı denemeler, oyun sonu kodu. Ortam: `BOARDSRC=screen PROMOMAP=qnbr`, `LIGHT=1`, `FLIP=1`,
  `FIFTY=100`, `QUIET=0.98` (sessiz hamle yanlılığı: 50 hamle beraberliğini zorlar).
- `botfuzz.py` — insan-bot: beyaz rastgele/yanlı oynar ve yasa dışı denemeler yapar; botun her hamlesi yasal
  hamleler arasında aranır; gerçek değerlerle (1/3/3/5/9) en iyi 2-ply hamlesini seçme oranı ölçülür.
  `ALPHA=br`, `LIGHT=1`, `SPIN=1`, `MATEPREF=1` (beyaz mat/pat arar → botun hamlesiz kaldığı son test edilir).
  Çıktıdaki `bot-spin-sonu`: botun hamle bulamayıp boş döngüde döndüğü oyun sonu sayısı.
- `qboot.py` — QEMU + SeaBIOS: tuş gönderip ekran görüntüsü alır (gerçek BIOS dumanı testi).
- `search/` — kaba kuvvet süperoptimizer (ağırlık ve terfi eşlemeleri için).
- `promokeys.py` (25.11'den beri): boot'ta tarama kodu (B/N/R tuşu), DOS'ta harf kuralı; `botpromo.py`: botun
  tek hamlesinin terfi olduğu bellekte kurulmuş konum, insanın son 5. tuşuna göre taş. `run16.py` int 16h'de
  AH'ye ABD düzeni tarama kodu yazar; `fuzz.py`'da `PROMOMAP=letters`.
- `regresyon.sh` — tüm teslim sürümlerinin son test turu; sonucu `TEST_SONUCLARI.txt`.

**Son test turu (19.11.2026, `TEST_SONUCLARI.txt`):** teslimdeki 13 sürüm boot ve .COM olarak yeniden
test edildi — 43 test satırı (hedefli vakalar + rastgele oyunlar + mat arayan beyaza karşı bot), **hepsi 0 hata**.
Ana insan-insan sürümünde (`ii_sonuc_50_donme`) bu turda her biçimde 2 mat, 1 pat ve 6 kez 50 hamle beraberliği
oluştu; ana bot sürümünde (`bot_light_ply1`) botun mat olup boş döngüde döndüğü son 5 kez oluştu, hepsi doğru.
Süre: boot turu ≈5 dk, .COM turu ≈13 dk (ply3/ply4 dahil).

**Son test turu (25.11.2026, `TEST_RESULTS.txt`, harfli terfi sürümleri):** `test.sh` 59 test satırı,
**hepsi 0 hata**: 640 rastgele iki kişilik oyun (53.010 hamle, 28.426 geçersiz deneme), bota karşı 326 oyun
(17.447 bot hamlesi), her tuş koduyla 1.548 terfi ve 40 bot terfisi. Süre: boot ≈3 dk, .COM ≈7 dk.
QEMU + SeaBIOS'ta 492 B ana sürümde Shift+N → at, r → kale; bot sürümü açılıp hamle verdi.

Toplam (proje boyunca): insan sürümlerinde binlerce rastgele oyun (her türev için yüzlerce), bot sürümlerinde
yüzlerce oyun; hepsi 0 hata ile kapandı. Gerçek SeaBIOS'ta (QEMU) insan, light, 50 hamle + dönme ve bot
sürümleri açılıp oynandı (16.11 öncesi).

---

## 12. Karşılaştırma ve rekor iddiası

Bilinen küçük satranç programları (kaynaklar 19.11.2026'da yeniden kontrol edildi):

| Program | Boyut | Platform | Kurallar (kaynağa göre) |
|---|---|---|---|
| 1K ZX Chess (David Horne, 1982–83) | 672 B | ZX81 (Z80) | rok, terfi, geçerken alma yok; bilgisayar rakip var |
| BootChess (Olivier Poudade, 2015) | 487 B (koordinatsız 468) | x86 boot | rok, küçük terfiler, geçerken alma yok; şah tehdide girebilir |
| Toledo Atomchess (Óscar Toledo, 2015→2019) | 481 → 456 → 446 → 392 → 326 B; güncel depo: boot 356, COM 352, "hack" COM 326 / boot 330 | x86 boot / COM | terfi, rok, geçerken alma yok; insan hamlesi denetlenmiyor; bilgisayar yasal temel hamleler oynar |
| Toledo Atomchess Reloaded | 779 B (2 sektör, yükleyicili) | x86 boot | oyuncu hamlesi denetimi, rok, geçerken alma; terfi yalnız vezire |
| Super Micro Chess (Stefano Maragò) | 583 B "full FIDE", 455 B "mini" | x86 DOS | full FIDE sürümü geçerken alma, rok ve küçük terfiyi yönetir; 583 B sürümün insan hamlesini tam denetleyip denetlemediği ve mat/pat gösterip göstermediği kaynakta yazmıyor. Mini: rok, küçük terfi, geçerken alma yok |
| Super Micro FIDE ZX81 1K (aynı yazar) | belirtilmemiş | ZX81 (Z80) | küçük terfi seçilebilir; kullanıcıdan yasal oynaması isteniyor, otomatik denetim "hataların %99'unu" önlüyor |
| ChesSkelet (Alex / Alejandro García, 2019→) | 377 → 363 → 352 B, sonra 269 B; **Guinness kaydı 354 B (23.09.2022)** | ZX Spectrum (Z80) | kuralların hepsi yok; tam sürümde "temel rok" |
| LeanChess (Dmitry Shechtman, 2019–20) | 288 B (ilk sürüm 328) | x86 DOS / BIOS | rok, geçerken alma, terfi yok; giriş denetlenmiyor; mat/pat tespiti yok |
| AttoChess (2026) | 272 B (önceki 276/278) | x86 DOS | rok, geçerken alma, terfi, mat tespiti yok; giriş denetlenmiyor |

Kaynaklar: https://en.wikipedia.org/wiki/1K_ZX_Chess · https://www.chessprogramming.org/BootChess ·
https://nanochess.org/chess6.html · https://github.com/nanochess/toledo-atomchess ·
https://smmax.sourceforge.net/ · https://sourceforge.net/p/smmax/blog/2015/10/the-mini-release/ ·
https://spectrumcomputing.co.uk/zxdb/sinclair/entries/0042948/smfide1k.txt ·
https://hackaday.com/2019/03/28/writing-a-very-tiny-chess-program ·
https://spectrumcomputing.co.uk/forums/viewtopic.php?p=22058 · https://talkchess.com/viewtopic.php?p=965646 ·
https://www.guinnessworldrecords.com/world-records/598436-smallest-chess-computer-programme ·
https://leanchess.github.io/ · https://nicholas-afk.github.io/AttoChess/

Gözlemler:
- Listedeki programların hepsi bilgisayar rakipli. İnsan-insan sürümlerimizin doğrudan karşılaştırılacağı
  bir sınıf yok (onlar oyuncu değil, kural hakemi). Rekor iddiası esas olarak insan-bot sürümüne dayanmalı.
- Kural kümesinde en yakın boot çözümü Atomchess Reloaded: 779 B, 2 sektör, yalnız vezire terfi.
  En yakın "full FIDE" iddiası Super Micro 583 B (DOS .COM); bizim insan-bot .COM'umuz 464 B.
- 300 B altındaki programların (LeanChess, AttoChess) hiçbiri insan girişini denetlemiyor ve
  rok / geçerken alma / terfi yapmıyor. ChesSkelet (Guinness kaydı) Z80'de ve kuralların hepsini uygulamıyor.

**İddia taslağı** (karşılaştırma doğrulandı; metin kararı bekliyor):
Bildiğimiz kadarıyla, insanın hamlesini tam denetleyen (kendi şahını tehdit altında bırakan hamle kabul
edilmez), roku tüm koşullarıyla, geçerken almayı ve seçmeli terfiyi (vezir/at/fil/kale) uygulayan,
**tek bir 512 baytlık boot sektöründe** çalışan en küçük x86 satranç programı:
- **insan-bilgisayar: 484 bayt** (`bot_light_ply1`; DOS .COM 464 B). Bot yalnız materyale bakar
  (1 yarım hamle). Oyun sonu gösterilmez: mat ya da patta oyun donar (FideLite L1_light gibi).
- **insan-insan: 510 bayt** ana sürüm (`ii_sonuc_50_donme`): mat/pat gösterimi + 50 hamle kuralı +
  tahta dönme. Aynı kurallar mat/pat gösterimiyle 479 B (`ii_sonuc`), göstergesiz 457 B (`ii_light`).

Dikkat edilecekler:
- Ölçü tanımı: boot kod baytı (dolgu ve 0x55AA imzası hariç). .COM boyutları da verilmeli.
- Kural kümesi açıkça yazılmalı: FideLite L1 + seçmeli terfi; üç tekrar yok; 50 hamle yalnız ana insan-insan sürümünde.
- İnsan-bot sürümünde oyun sonu göstergesi yok ve bot terfide insanın son terfi tuşunu kullanıyor;
  iddia metninde açıkça yazılmalı.
- Doğrulanamayanlar: Super Micro 583 B'nin insan hamlesini tam denetleyip denetlemediği ve mat tespiti;
  Atomchess Reloaded'in mat tespiti ve rok koşulları. Bu yüzden iddia "bildiğimiz kadarıyla" kalmalı.
- Test yöntemini (python-chess hakemi, oyun sayıları) README'de yayımlamak iddiayı güçlendirir.

---

## 13. Açık işler ve öneriler

- Repo adı, iddia metni, lisans, İngilizce README (bölüm 0).
- Gerçek donanımda (disket/USB) deneme.
- Repo düzeni: şu an `src/`, `bin/`, `arac/`, `notlar/`, `derle.sh`, `regresyon.sh`. İngilizce adlar
  (`tools/`, `docs/`, `build.sh`, `test.sh`) ve ana/ekstra klasör ayrımı istenirse betiklerdeki yollar da değişmeli.
- İsteğe bağlı: ply3 max boot (3 B eksik), FRONT=0xFF denemesi (insan, −1?), Backspace/satır düzenleme
  desteğinin bayt maliyetini ölçmek.
- ply ≥ 3'te mat/pat ayrımı (bot patı kovalamasın) — "yalnız materyal" kapsamı dışında.

---

## 14. Arşiv içeriği

- `README.md` — bu dosya (rapor + README).
- `src/l1yeni.asm` — insan-insan sürümleri; seçenekler: `boot`, `bios`, `LIGHT`, `REDRAW`, `FIFTY` (`PLIES`), `FLIP`.
- `src/l1bot.asm` — insan-bot (light) sürümleri: `PLY=1..4`, `OR2`, `SPIN`, `boot`, `bios`.
- `bin/` — bölüm 2'deki 13 sürüm: boot'a sığan 10'unun `.bin` + `.img` + `.com`'u, sığmayan 3'ünün
  yalnız `.com`'u (33 dosya).
- `derle.sh`, `regresyon.sh`, `TEST_SONUCLARI.txt`.
- `arac/` — `run16.py`, `targeted.py`, `fuzz.py`, `botfuzz.py`, `qboot.py`, `search/`.
- `notlar/` — çalışma notları (`alfabe.md`, `eksen3.md`); tarihî kayıt: eski boyutlar ve eski dosya adları içerir.
