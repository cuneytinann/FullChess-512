# Eksen 3 — sıfırdan yazım: mimari tartısı (insan vs insan, boot)

Taban (port, A2): 486 B kod. Dağılım: başlangıç 59, ekran 41, yedek 13, chk 9, giriş 27, tuş 29,
sonuç 13, üretici 124 + tablolar 31, try 139.

## Mimariler (hesap)
1. Üretici + yanıt taraması + kopyala-oyna (bugünkü): taban.
2. Doğrulayıcı V(i,f) (h*v / kareler): oyun sonu için tüm (i,f) çiftleri + her yasal adayda
   şah bulma + rakibin tüm kareleri için V. Kazanç: girilen hamle karşılaştırması gider (-20).
   Kayıp: çift döngüsü (~20), saldırı döngüsü + şah bulma (~30), sarmal (~15), V'nin geometrisi
   (dr/dc, kareler, işaret, yürüyüş ~70) üreticinin tablo+adım koduyla (~70) başa baş.
   Net yaklaşık +30. Ayrıca yanıt taraması 5 baytken saldırı testi ~30 bayt.
3. Tahtayı her hamlede çevirmek (hep beyaz oynar): taraf bağımlı kod -23, ama çevirme döngüsü
   (renk biti yalnız taşlarda: koşullu) ~30, ekranı ve girişi geri çevirme ~20 -> net ~+30.
4. Hamle listesi + seçim: üretici + liste yazma + arama + ayrıca oyna -> daha büyük.
5. Kopya tahta / segment: geri koyma kadar kopyalama + segment yönetimi -> daha büyük.
6. Ekrana doğrudan VRAM: CR/LF kalkar ama ES değişimi, öznitelik, yankı/imleç -> daha büyük.
Sonuç: üretici mimarisi kalıyor; sıfırdan yazım aynı mimariye varır. Kazanç ancak yapı içi.

## Yazarken bulunanlar (mimariden bağımsız)
- Ekran: çerçeve hücreleri çift/tek: çift = 0xFF (CR), tek = 0xBA (LF, tablo[2]+0xBA = 0x10A).
  putc sonrası AL = karakter & 0x0F (tuş kuyruğu) -> `cmp al,0x0a` ile satır atlama: -5.
  Dolgu `stosw` ile çift yazar (çiftin iki hücresi aynı tahta-içi/dışı): +3 (salc'li dolguya göre +4).
- Terfi/giriş: `push di; mov di,promo; stosb; pop ax; stosw; xchg ax,si; stosw` (inp = promo+1): -1
- rply: `mov cl,1` yerine `inc cx` (cl her çağrıda 0): -1
- Tutma çıkışı: `popa; pop ax; xor ch,BLACK; stc; ret` yerine `sub sp,byte -18; dec cx; ret`
  (rply zaten tarafı çevirdi ve cl=1 yaptı; SP0=0 olduğundan çıkarma borç verir: CF=1): -2
- try: `cmp dh,1; je` yerine `dec dh; jz` (dx sonra zaten ezilir, popa geri koyar): -1
- Rok: AL = ŞAH|U|ch tutulur, kale = `xor al,ŞAH^KALE`; adım kontrolü `di - [bx] == si`
  ve yürüyüş bx = si'den başlar (ayrıca `mov bx,si` yok): -2
- (UI değişirse) tuş: `and ax,0x0f` yerine `aam 16` + sabit düzeltme: -1 ama büyük harf dosya girişi bozulur. Alınmadı.

## SONUÇ (insan vs insan, kural bazlı sıfırdan yazım) — l1yeni.asm
Uygulanan ve doğrulanan kazanımlar (486 -> 481 boot kod, -5):
- rply `inc cx` (cl her çağrıda 0): -1
- try `dec dh; jz` (dh sonra eziliyor): -1
- terfi/giriş `push di; mov di,promo; stosb; pop ax; stosw; xchg ax,si; stosw` (promo=inp-1): -1
- tutma çıkışı `sub sp,byte -18; dec cx; ret` (popa/pop/xor ch/stc yerine; rply tarafı
  çevirdi + cl=1 yaptı, sabit çağrı derinliğinde SP<0xFFEE -> CF=1): -2
Boyutlar: boot kod 481 B (taban 486), .COM 459 B (taban 464).
Doğrulama: targeted 22/22 (COM + boot, BOOTREGS=hostile), fuzz 900 oyun 0 hata
(castle 443, ep 138, promo 412, mate/stale görüldü), QEMU+SeaBIOS gerçek boot e4 e5 doğru.

Alınmayanlar:
- castling kale `xor` + `cbw` adımı (-2): di-si==adım doğrulaması düşürülemiyor (yatay şart),
  net kazanç çıkmadı; en karmaşık kural, riske değmez.
- ekran çift/tek CR/LF (-5 iddia): 16-geniş düzende dolgu parite mantığı (~+7..8 B) ekranın
  kazancını (~-5) yiyor; not'taki -5 farklı temel (salc-dolgu / COM int29) varsayıyordu.
  Bu boot/A2 yapısında güvenilir kazanç değil. Alınmadı.
Mimari değişmedi: sıfırdan yazım da üretici+yanıt taraması+kopyala-oyna mimarisine varıyor;
kazanç yalnız yapı-içi. Dosyalar: l1yeni.asm, l1yeni_human.com, l1yeniboot.bin/.img.

## LIGHT (sitedeki L1_light gibi: oyun sonu göstergesi yok) — l1yeni.asm -DLIGHT
L1_light.html: "hiç yasal hamle kaldı mı" taraması (L1'deki b.every(..!L)), sonuç (B#/W#/SM),
z bitti bayrağı ve C! şah göstergesi yok; yasa dışı hamle geri alınır, oyun kendiliğinden donar.
Bizde düşenler: root'taki `xor bp,bp` (2), try'daki `inc word [si+4]` (3), chk'deki
`or bp,bp; jz over` (4), over bloğu (rply+salc+and+add+putc+jmp $ = 13) -> boot -22.
- -DLIGHT:          boot 459 B (481'den -22), .COM 439 B (459'dan -20)
- -DLIGHT -DREDRAW: boot 457 B (-2 daha): girişten önceki boş root çağrısı kalkar,
  döngü "giriş -> root -> tahtayı çiz"; bedeli: reddedilen hamleden sonra da tahta yeniden çizilir.
Doğrulama: hakemlere LIGHT=1 kipi eklendi (bitişte tüm sözde-yasal hamleler + rastgele çiftler
gönderilir; tahta değişmemeli, program çıkmamalı, '#'/'=' basılmamalı). targeted 22/22
(COM+boot, her iki varyant); fuzz 900 oyun 0 hata (mat 35, pat 23 konumunda bitiş sonrası
tüm denemeler reddedildi); ters kontrol: LIGHT hakemi normal sürümde mat/pat vakalarını FAIL
veriyor; QEMU+SeaBIOS: Çoban matı sonrası e1f2 reddedildi.

## Rok yeniden yazımı (-2, tüm sürümler)
AL = SAH|U|renk tutulur (mov al,K|U; or al,ch; cmp al,[si]); adım AH'de (mov ah,[bx]);
ilk adım kontrolü bx=si+adım == di; kale = xor al,SAH^KALE. İlk denemede hata: ilk adım
kontrolü bx'i kareye çevirdikten sonra .r'ye atlıyordu, bh=TP geri yüklenmiyordu ->
üreteç sonraki yönleri tahta sayfasından okudu (Rg1 reddedildi). jne .no ile düzeldi.
Temel: 481 -> 479 boot, 459 -> 457 .COM. Light 457, Light+Redraw 455.

## 50 hamle (-DFIFTY) ve tahta dönme (-DFLIP)
- FLIP (+11): main'de maske `mov al,ch; aam 0x20; aad 0x77; xchg dx,ax` (7), döngüde
  `mov di,si; xor di,dx` ile okuma (4). XOR 0x77: kare (r,c)->(7-r,7-c), çerçeve çerçevede,
  sayfa aynı (L1'deki w^7<<t/2'nin karşılığı). Giriş koordinatları mutlak kalır.
- FIFTY (+20): sayaç hm = ledger+10 (yedeklenen/geri konan bölge, FRONT'tan sayar).
  try'da piyon yolu .pp'de stc; .np'de `xchg [di],al; adc al,0` (alma ya da piyon -> !=0)
  -> sıfırla (mov byte [hm],FRONT-1) + inc. chk'de mat/pat kontrolünden SONRA
  `cmp byte [si+10],(FRONT+PLIES)&255; je over.d` (tarama sonunda si=save; eşitlikte CF=0
  -> '='). PLIES=100 (50 hamle); FideLite L2'nin otomatik 75 hamlesi -DPLIES=150, aynı bayt.
  FideLite: L2 otomatik 75 (n>149), 50 hamle L3'te talep.
- Boyutlar (rok sonrası): FLIP 490, FIFTY 499, FIFTY+FLIP 510 (tam sığıyor, 0 boş).
  .COM: 468 / 477 / 488.
Doğrulama: hakemlere FLIP=1 (siyah sıradaysa beklenen tahta ters), FIFTY=n (halfmove_clock),
QUIET=p (sessiz hamle yanlılığı) eklendi. targeted 27/27 (5 yeni 50-hamle vakası: tam eşik,
bir eksik + piyon, piyon sıfırlar, alma sıfırlar, rok sayılır). Fuzz: temel 800 oyun (390 rok),
FLIP 300, FIFTY 250 sessiz (27 beraberlik), ikisi 400 yanlı + 250 sessiz (23 beraberlik):
hepsi 0 hata. Ters kontroller (normal sürüm) başarısız. QEMU+SeaBIOS: e4 sonrası 180°,
100 yarım hamle sonrası '='. Dosyalar: l1fullboot.bin/.img, l1full.com, l1flipboot.bin, l1fiftyboot.bin.
Yedek bayt istenirse: FRONT=0xFF + dolguda `neg al; salc` (-1, denenmedi).

## Bot + kural iç içe, sıfırdan (l1bot.asm, light, yalnız materyal) — 2026-11-16 02:59-03:22
Tasarım: tek üreteç; yaprak tarama (rakip cevapları) hem yasallığı (şah alınıyor mu) hem en iyi
almayı aynı geçişte verir. İki geçiş: 1. geçiş en iyiyi best/inp'e yazar (insan sırasında da: best
max olsun diye), bot ise 2. geçiş inp'i oynar; insan girişi aynı tarama ile doğrulanır.
Sonuç kodu yok: bot hamle bulamazsa girişe düşer, oyun donar. Ağırlık aam 5/aad 2 (P1 F2 A2 K3 V4).
- PLY=1 (aldığı): boot 492, .COM 472
- PLY=2 (aldığı - rakibin en iyi alması, gerçek max): boot 500, .COM 480 (OR yaklaşımı: 496/476)
- PLY=3 (aldığı - max_cevap(cevabın aldığı - benim en iyi almam)): .COM 498 (OR 494); boot 518 (OR 514): 512'ye sığmıyor.
  ply3 teknikleri: yaprak dışı seviyelerde bp = seviye tamponu (0x6007/0x6107: pozitif, alt 3 bit 111
  -> koşulsuz max/or bp'yi bozmaz); tampon başında [best][inp], geri koyma +6'dan; node: = yedekle ve
  root'a düş (ana döngü ve 2. seviye ortak); seviyeler kök 1 / ikinci 2 / yaprak 3 -> inc cx sonrası jpe
  ve move'da test cl,cl; jpe; 2. seviye sonucu mov al,[best2]; xchg bp,ax (CF korunur, cbw gereksiz).
  İlk sürüm 550 -> 538 -> 518.
  Zayıflık: rakibin yasal cevabı yoksa (mat ya da pat) +121 sayılır: bot patı da kovalayabilir.
  İnsan hamlesinin yasallığı da 3 kat aranır (yavaş ama doğru).
Doğrulama: botfuzz'a LIGHT eklendi (bitişte tahta değişmemeli). ply1 130 oyun, ply2 190 oyun
(boot+COM, hasım yazmaçlar), ply3 max 40 + OR 26 oyun (COM, MAXINSN yükseltildi): 0 hata.
Bot, hakemin gerçek değerlerle (1/3/3/5/9) en iyi 2-ply hamlesini seçme oranı: ply1 %84-86,
ply2 %96-98. Sonuç kodlu eski botlar (l1yeni -DBOT[-DGREEDY]) rok sonrası 504/508: 80 oyun 0 hata.
QEMU: ply2 light boot, e4 -> Nc6, Qh5 -> Rb8.
Envanter: teslim/derle.sh her özellik kümesinin en küçüğünü boot(.bin/.img)+.COM üretir (36 dosya).

## Botta sıfırdan yazım gerçekten kazandırdı mı? (04:30 kontrolü)
ply1/ply2: hayır. 504/508 -> 492/496 düşüşün tamamı sonuç kodunu atmaktan (-20). Benim yeni
döngüm (bot donunca girişte beklesin diye) eski döngünün sonuç kodsuz hâlinden 8 bayt BÜYÜKtü.
-DSPIN = eski tek döngü (call root; jc main; test ch,ch; jnz chk; giriş; jmp chk): bot hamlesizse
döner (jmp $ gibi). SPIN: ply1 484/464, ply2 492/472, ply2-OR 488/468, ply3 513✗/493,
ply3-OR 509/489 (boot'a sığıyor). Kuralla iç içe değerlendirme (yanıt taraması = yasallık +
tehdit) eski 2-ply botta zaten vardı (OR). Yeni olan: gerçek max (+4) ve ply3 (550 -> 509).
Doğrulama SPIN: 250 oyun + MATEPREF (beyaz mat arar) 92 oyun, 7 bot-dönme sonu: 0 hata.
