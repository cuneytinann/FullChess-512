# Alfabe ekseni — kısıtlar (taban: insan-boot 491 B kod)

Bugünkü alfabe: P1 F2 K3 V4 A5 Ş6, renk 0x20, UNMOVED 0x80 (Ş/K), boş 0, çerçeve 0x87.

## Kod-bağımlı sorular (yer, bayt)
- sq: kendi taşı mı? `and 0x7f; xor ch; dec; cmp 6; jnc` (9) + beyaz piyon `cmp [si],2; sbb 0xfb` (5)
  + yön sayısı `mov ah,0x0c; and ah,al` (4) + tablo `mov bl; xlatb; xchg` (4) + offsets tablosu (7)
- cap: rakip/kendi/çerçeve/şah ayrımı `xor ch; and 0x7f; sub 0x20; cmp Ş; ja; jne; stc; ret` (14)
- cont: kayan taş mı? `mov al,[si]; cmp [di],0; jnz; and 7; sub 2; cmp 3; jc` (15)
- try: piyon mu `test al,6` (2), UNMOVED sil `and 0x7f` (2)
- rok: `xor ch; cmp Ş|U` / `mov ROOK|U; or ch` (8)
- ekran: `and 7; mov bx,chars; xlatb; add [si]; and 0x7f` (10) + tablo (8)
- kurulum: başlangıç dizisi (8), `or 0x20`, siyah piyon (4), beyaz piyon `inc` (3)
- terfi: `inc ax; and al,3; add al,2` (5) + try `or al,ch` (2)
- sıra değiştirme: `xor ch,0x20` x2 (6)
- (bot) ağırlık `aam 5; aad 2` (4)

## Aksiyomlar (motorun yapısından; bırakmak = baştan yazmak)
- boş = 0 (vacate `xchg al,[si]` 0 ile, `cmp [di],0`, inc/dec boş testi, rok yürüyüşü, `sub [bx],al`)
- tür alttaki 3 bitte; çerçevenin alt 3 biti 7 (ekran: tablo[c&7]+c, çerçeve -> CR)
- beyaz piyon = 1 (`inc` kurulumu + `cmp [si],2; sbb` beyaz piyon tespiti + `test al,6`)

## Hareket noktaları (sınanacak)
- renk biti 0x20 (küçük harf = +0x20). Alternatif: tümleyen (siyah = ~beyaz, `not ch` -2) -> ekran +4 (hesap)
- UNMOVED 0x80 (ekranda harf+0x80 & 0x7f temiz). 0x40/0x08/0x10: ekranda taşma -> strip önce (+)
- tür sıralaması: yön sayısı hilesi 4-yönlüleri (P,K,F) t<=3, 8-yönlüleri (V,A,Ş) t>=4 ister;
  kayan taş aralık testi K,F,V = {2,3,4}; şah tespiti Ş = en büyük. Bu üç kural sıralamayı
  neredeyse kilitliyor: P1, {F,K}={2,3}, V4, A5, Ş6.
- Boşta bitler: 3, 4, 6. Bunlar "özellik biti" olarak kullanılabilir (site: "bir bit çapraz, bir bit düz").

## Aday aileleri
- A0: bugünkü (taban)
- A1 "kayan taş biti": K,F,V'ye S biti (0x08/0x10/0x40). cont -> `cmp [di],0; jnz; test byte [si],S; jnz` (-5).
  sq/cap strip maskesi 0x7f -> 0x7f&~S (aynı boy). Ekran tablosu S'yi telafi eder. Terfi eşlemesi S'li kod üretmeli (ara).
- A2 "V=6" (kayan = bit1: P1 {F,K}{2,3} {A,Ş}{4,5} V6): cont bit testi (-5) ama Ş en büyük değil -> cap +2 (ara)
- A3 tümleyen renk: toggles -2, ekran +4 (kur, doğrula)

## Sonuç (ölçüldü)
- A2* = P1 K2 F3 Ş4 A5 V6, çerçeve 0x8F, cap: `xor al,0x23` (şah->7), cont: `test byte [si],2`,
  terfi: `inc ax; xor al,0x83; aam 9`. insan-boot 491 -> 486, .COM 469 -> 464. targeted 22/22, fuzz 60 oyun 0 hata.
- A1 (ayrı S biti): terfi <=6 B yok -> en iyi -3 (eledi)
- A2'nin diğer 3 dizilimi: terfi 6 B ya da yok (A2* tek 5 B)
- tümleyen renk: -2 (not ch) +4 (ekran) = +2 (hesap)
- bot notu: A2* cap çıktısında fil -> 0 = sessiz hamle değeri; bot aşamasında ayrı ele alınacak

# Geometri ekseni (ölçüldü, A2 alfabesiyle)
- 16 genişlik (taban): insan-boot 486
- 10x8, tahta sayfa sonunda (dikey kenar 8-bit taşmadan): 495 (+9). fill +6 (aam 10), e.p./atlanan +4,
  çift adım +1, ekran -2. fuzz 60+30 oyun 0 hata. Yan bulgu: ekran tahtadan sonra durur (boş satır yok).
- 12/11 genişlik: 10 ile aynı sınıf (aam N, satır xor hilesi yok) ~+9 (hesap)
- 10x12: sayfa taşması dikey kenarı zaten veriyor -> 10x8 + boş satırlar (>= +9)
- 8x8: e.p./çift adım/terfi hileleri 8'lik satırla çalışır (xor 8) ama yatay taşma her adımda
  kontrol ister + ekranda satır sayacı: +15..25 (hesap). h*v doğrulayıcı = farklı mimari (eksen 3).
