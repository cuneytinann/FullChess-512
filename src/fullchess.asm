; fullchess.asm -- FullChess, two players, x86 16-bit (boot sector or DOS .COM).
;   Rules: all piece moves, legality (no move may leave or put your own king in check),
;   castling with all its conditions, en passant, promotion to queen/knight/bishop/rook,
;   checkmate and stalemate. Own code; credits and the parts that still follow Toledo
;   Atomchess (board page, setup loop shape, frame newline) are listed in the README.
;   Promotion: the 5th key of a move picks the piece: N knight, R rook, B bishop (either case),
;   any other key a queen. Boot sector: by BIOS scan code (the physical key); DOS: by letter.
;
;   nasm -f bin [-Dboot] [options] fullchess.asm -o x.bin     (without -Dboot: DOS .COM)
;     -Dboot   : org 0x7C00, BIOS I/O, sets up segments and stack, halts at game end (jmp $),
;                padded to 510 bytes + 0x55AA signature (nasm errors out if code exceeds 510)
;     -Dbios   : .COM, but I/O through BIOS (int 10h/16h)
;     -DLIGHT  : no game-end indicator; at mate/stalemate no input is accepted (game freezes)
;     -DREDRAW : (only with -DLIGHT) board is redrawn after every input
;     -DFIFTY  : (without LIGHT) automatic draw after 50 moves = 100 plies; -DPLIES=150: 75 moves
;     -DFLIP   : board rotates 180 degrees when Black is to move (input stays absolute)
;   Sizes, boot code / .COM (build.sh): fullchess (-DFIFTY -DFLIP) 493/476 (main version),
;     2p 467/450, 2p50 (-DFIFTY) 482/465, 2pflip (-DFLIP) 478/461,
;     2plight (-DLIGHT) 445/431, 2plightr (-DLIGHT -DREDRAW) 445/431.
;   Piece codes: P1 R2 B3 K4 N5 Q6, colour 0x20, UNMOVED 0x80, black pawn mark 0x08, frame 0xFF.
;   Techniques: square from keys with aad 0xF0; display splits colour/type with aam 0x20 and
;   puts the colour back as the lower-case bit with aad 0x20; one descriptor byte per piece
;   (28*directions + list offset) split by aam 28; target square stepped in DL (DH = board page);
;   pawn moves classified by the direction byte (odd = diagonal, +-32 = double step).
;   Inline comments below are in Turkish (K=kale/rook, F=fil/bishop, S=sah/king, A=at/knight,
;   V=vezir/queen); see docs/DEVLOG.tr.md for the full development record.
        cpu 286
%ifdef boot
%define bios
ORIGIN  equ 0x7c00              ; BIOS sektoru 0000:7C00'a yukler
%else
ORIGIN  equ 0x100
%endif
        org ORIGIN

PAWN    equ 1
ROOK    equ 2                   ; alfabe A2: kayan taslar (K,F,V) bit1'de, 4-yonluler <=3
BISHOP  equ 3
KING    equ 4
KNIGHT  equ 5
QUEEN   equ 6
FRONT   equ 0xff                ; alt 3 bit 7 (ekran), 0x7F^3 > 7 (cap'te sahin ustunde); dolgu: neg al; salc
BLACK   equ 0x20
BPAWN   equ 0x08                ; siyah piyon isareti (alt 3 bit yine PAWN: ekran, piyon ve kayma testleri ayni)
UNMOVED equ 0x80                ; hic oynamamis sah/kale (yalniz rokta sorulur, baska yerde silinir)

board   equ 0x7f00
ledger  equ board-0x80          ; tahtanin onundeki 128 bayt: gecerken alma karesi burada
enp     equ ledger+0x08         ; gecerken alma hedefi (yedeklenen bolgede)
hm      equ ledger              ; FIFTY: yarim hamle sayaci, FRONT'tan sayar (yedeklenen bolgede; [si] ile okunur)
%ifdef FIFTY
tbase   equ hm                  ; try icinde si: hm = [si], enp = [si+8]
%else
tbase   equ enp                 ; try icinde si: enp = [si]
%endif
%ifndef PLIES
PLIES   equ 100                 ; 50 hamle = 100 yarim hamle (FideLite L2'nin otomatik 75'i: -DPLIES=150)
%endif
save    equ 0x8000              ; konum yedegi: yedek dongusu 510/512 bayt yazar, geri koyma 250 bayt
inp     equ 0xfffc              ; girilen hamle yiginin dibinde: [varis][cikis] (girişte push edilir)
%define LO(x) (((x)-start) & 255)
%define TP   ((((desc)-start)+ORIGIN)>>8)        ; tas tanimlari ve yon tablolarinin sayfasi

%macro putc 0
%ifdef bios
        call display
%else
        int 0x29
%endif
%endmacro

start:
%ifdef boot
        ; Terfi tablosu acilis kodunun baytlarinda (yalniz bir kez calisir):
        ; B9 [13 30 FC 31 C0] -> ptab = start+1: R kale, B fil, (sah yeri: FC tarama kodu
        ; olamaz), N at; bekci = C0 (acilistan sonra her tusla ezilir). LO(ptab) = 1:
        ; eslesmede DI'nin alt bayti dogrudan tas kodu (2 kale, 3 fil, 5 at, 6 vezir).
        mov cx,0x3013           ; ayni zamanda dolgu sayisi: 0x7E80..0xAE92
        cld
        xor ax,ax               ; BIOS DS/ES/SS:SP icin soz vermiyor: hepsini kur
        mov ds,ax
        mov es,ax
        mov ss,ax
        mov sp,ax               ; yigin 0000:FFFE'den asagi
        mov di,ledger
%else
        mov di,ledger
        mov ch,2                ; CX >= 0x200: defter + tahta sayfasi (0x180 bayt) yeter
%endif
fill:   push di
        pop ax
        and al,0x88
        neg al                  ; CF = (al != 0)
        salc                    ; al = CF ? FRONT (0xFF) : 0
        stosb
        loop fill
        mov si,initial
        mov di,board
        mov cl,8
setup:  lodsb
        mov [di+0x70],al
        or al,BLACK
        stosb
        mov byte [di+0x0f],PAWN+BLACK+BPAWN
        inc byte [di+0x5f]
        loop setup
        jmp short main          ; try'in basi araya girdi (tutma cikisi main'e dusecek)

        ; deneme: hamleyi tam etkileriyle yap, rakip yanitinda sah almasi ara.
        ; Gecerli ve girilen (inp) hamleyse tahtada birak ve dogrudan main'e dus
        ; (try'in basi bu yuzden main'in hemen onunde; yigini girdi sifirlar).
try:    pusha
        mov al,0
        xchg al,[si]
        mov si,tbase            ; si artik serbest: enp/hm kisa adresle (tbase asagida)
        and al,0x7f             ; tas artik oynamis: UNMOVED silinir
        test al,6               ; piyon mu?
        jnz .np                 ; degilse BX tablo isaretcisi: gecerken alma yok
        mov bx,di
        xor bl,0x10
        cmp di,[si+enp-tbase]
        jne .ne
        mov [bx],cl             ; gecerken alinan piyon (try'da cl = 0)
.ne:    dec ah                  ; ah = yon sayaci: 1 ise cift adim (ah bundan sonra serbest)
        jz .pp                  ; cift adim: BX atlanan kare
        lea dx,[di+0x10]
        test dl,0x60
        jnz .nq
        push di
        mov di,ptab
        mov al,[di+4]           ; bekci = 5. tusun kodu: bulunamazsa sonda kendisi -> vezir
.p:     scasb
        jne .p
        xchg ax,di              ; AL = ptab+i+1 (alt bayt)
%ifndef boot
        sub al,LO(ptab-1)       ; -> 2 kale, 3 fil, 5 at, 6 vezir (bekci); boot'ta LO(ptab) = 1
%endif
        pop di
        or al,ch
.nq:    mov bh,0                ; BX artik kare degil
.pp:
%ifdef FIFTY
        stc                     ; piyon hamlesi (tas olmayanlar .np'ye CF=0 ile gelir: test)
%endif
.np:    mov [si+enp-tbase],bx
%ifdef FIFTY
        xchg [di],al            ; al = alinan tas (0: bos)
        adc al,0xff             ; CF = alma ya da piyon
        salc                    ; al = CF ? 0xFF : 0
        inc byte [si+hm-tbase]
        or [si+hm-tbase],al     ; sifirla: FRONT
%else
        mov [di],al
%endif
        call rply               ; CF=1: gecersiz
        jc .u
        mov si,sp
%ifndef LIGHT
        inc word [si+4]         ; cercevedeki BP: gecerli hamle sayaci
%endif
        mov di,inp
        cmpsw                   ; girilen hamle bu mu?
        jne .m
        cmpsw
        jne .m
                                ; tutma: dogrudan main'e duser (ch zaten rakip; cl = 1: yedek dongusu sifirlar)
main:                           ; tutma cikisi (try) buraya atlar; yigini giris sifirlar
%ifdef FLIP
        mov al,ch               ; sira siyahta (ch=0x20) -> tahta 180 derece doner
        aam 0x20                ; ah = 1 / 0
        aad 0x77                ; al = 0x77 / 0, ah = 0
        xchg dx,ax              ; dx = okuma maskesi
%endif
        mov si,board-8          ; tahtayi ciz (yalnizca buradan cagriliyordu: gomuldu)
.l:
%ifdef FLIP
        mov di,si
        xor di,dx               ; kare (r,c) -> (7-r,7-c); cerceve cerceveye, sayfa ayni
        mov al,[di]
%else
        mov al,[si]
%endif
        and al,0x67             ; UNMOVED ve bit 3-4 gider: tas = renk|tur, cerceve = 0x67
        aam 0x20                ; AH = renk (cerceve 3), AL = tur (cerceve 7)
        mov bx,chars
        xlatb                   ; buyuk harf
        aad 0x20                ; AL += 0x20*renk: siyah kucuk harf; cerceve chars[7]+0x60 >= 0x80
        jns .c
        add si,byte 7
        mov al,0x0d
        putc
        mov al,0x0a
.c:     putc
        inc si
        jns .l
        mov di,si               ; si = save (cizim 0x8000'de bitti)
        mov si,ledger
.b:     movsw                   ; konum yedegi: 256 word (save'in otesi bos bellek, zararsiz)
        inc cl                  ; cl 0 ya da 1'den (tutma cikisi) yine 0'a; ch korunur
        jnz .b
%ifndef REDRAW
chk:    call root               ; donerse hamle oynanmadi (oynanirsa try main'e atlar)
%endif
%ifndef LIGHT
        or bp,bp                ; gecerli hamle sayisi
        jz over
%ifdef FIFTY
        cmp byte [si+hm-ledger],(FRONT+PLIES)&255  ; si = save (tarama bitti): sayacin yedegi
        je over.d               ; esitlikte CF=0 -> '=' (mat onceliklidir: yukarida bakildi)
%endif
%endif                          ; LIGHT: sayac yok; hamle kalmadiysa hicbir giris kabul edilmez
        xor sp,sp               ; inp = yiginin dibi (FFFC varis, FFFE cikis)
        call key2
        push di                 ; cikis
        call key2
        push di                 ; varis
        call key                ; 5. tus (yankili): tarama kodu ptab bekcisine yazilir
%ifdef REDRAW
        call root               ; LIGHT+REDRAW: oynansin ya da reddedilsin, tahta yeniden cizilir
        jmp main
%else
        jmp chk
%endif
%ifndef LIGHT
over:   call rply               ; sira kimdeyse onun sahi aliniyor mu?
.d:     salc
        and al,'#'-'='
        add al,'='
        putc
%ifdef boot
        jmp $                   ; donulecek isletim sistemi yok: dur
%else
        int 0x20                ; (yigin sifirlanmis olmayabilir: ret ile donulmez)
%endif
%endif

try.m:  clc
try.u:  mov si,save
        mov di,ledger
        mov cx,125
        rep movsw               ; geri koy (ledger + tahtanin satir 0-7'si)
        popa
        jc try.r
        ; rok: sah, dokunulmamis; bu ilk yatay adim gecerliydi. Sahtan kaleye
        ; kadar bos, ucta dokunulmamis kendi kalesi; sah su an sah altinda degil.
        ; Basarida kale gecilen kareye konur, ZF=1 CF=0 doner.
        mov al,KING|UNMOVED
        or al,ch
        cmp al,[si]             ; hic oynamamis kendi sahim mi? (AL = SAH|U|renk kalir)
        jne try.r
        pusha                   ; uretecin yazmaclari (bx yon, ah sayac, dx hedef): .no geri yukler
        mov ah,[bx]             ; AH = bu yonun adimi
        mov bx,si
        add bl,ah
        cmp bx,di               ; ilk adim mi?
        jne try.no
try.w:  add bl,ah               ; sayfa icinde yuru (ureteckteki gibi sarar)
        cmp byte [bx],0
        je try.w
        xor al,KING^ROOK        ; AL = KALE|U|renk
        cmp al,[bx]             ; hic oynamamis kendi kalem mi?
        jne try.no
        pusha
        call rply               ; sah su an sah altinda mi?
        popa
        jc try.no
        sub [bx],al             ; kaleyi kaldir; ZF=1 CF=0: ikinci adimi uret
        mov [di],al             ; kale gecilen kareye (rokta sah zaten oynamis olur)
try.no: popa
try.r:  ret

chars:  db '.PRBKNQ'            ; [7] = sonraki bayt (boot: initial[0] 0x82, DOS: 'r'): +0x60 -> isaretli
%ifdef boot
ptab    equ start+1             ; tablo acilis kodunda (yukari bak)
%elifdef bios
ptab:   db 0x13,0x30,0xff,0x31  ; terfi, tarama kodlari: R kale, B fil, (sah yeri), N at
%else
ptab:   db 'r','b',0,'n'        ; terfi: tur-2 sirasiyla (0: sah yeri, hicbir tus|0x20 ona esit olmaz)
%endif
initial:                        ; (DOS: initial[0] = ptab+4 bekci yeri; kurulumdan sonra okunmaz)
        db ROOK|UNMOVED,KNIGHT,BISHOP,QUEEN,KING|UNMOVED,BISHOP,KNIGHT,ROOK|UNMOVED
%ifndef boot
        times ((((($-$$)&255)+32)>>8))*((256-(($-$$)&255))&255) db 0 ; DOS: desc..pawnb tek sayfada
%endif
        ; tas tanimi: 28*yon_sayisi + listenin dirs icindeki yeri; aam 28 ikisini ayirir
desc:   db 28*4+pawnw-dirs, 28*4+rookd-dirs, 28*4+bishd-dirs, 28*8+rookd-dirs, 28*8+disp-dirs, 28*8+rookd-dirs
        db 0,0                  ; (6, 7: bu kodlar tahtada yok)
        db 28*4+pawnb-dirs      ; 8: siyah piyon (PAWN|BPAWN)
dirs:
disp:   db 33,31,18,14,-14,-18,-31,-33
rookd:  db 1,-1,16,-16
bishd:  db 15,17,-15,-17
pawnw:  db -15,-17,-16,-32
pawnb:  db 15,17,16,32
        times -((((desc)-start)^((pawnb+3)-start))>>8) db 0 ; desc..pawnb ayni sayfada olmali

rply:   xor ch,BLACK            ; rakip, yanit katmani
        inc cx                  ; cl her rply cagrisinda 0 -> 1 (ch uzerine tasma yok)
root:
%ifndef LIGHT
        xor bp,bp               ; gecerli hamle sayaci
%endif
play:   mov si,board
        mov bh,TP
sq:     mov al,[si]
        and al,0x7f             ; UNMOVED'u at
        xor al,ch
        dec ax
        cmp al,BPAWN+1
        jnc nsq                 ; kendi tasi degil (0-5: P R F S A V, 8: siyah piyon)
        mov bl,LO(desc)
        xlatb                   ; 28*sayi + yer
        aam 28                  ; AH = yon sayisi (4/8), AL = listenin yeri
        add al,LO(dirs)
        mov bl,al               ; bx = yon isaretcisi
dir:    mov dx,si               ; DH = tahta sayfasi, DL = kare
step:   add dl,[bx]             ; sonraki kare (sayfa icinde sarar)
        mov di,dx
        mov al,[di]
        test byte [si],6        ; piyon mu? (yalniz P1'de bit 1-2 bos)
        jz pawn
        test al,al
        jz move                 ; tas, bos kareye
cap:    xor al,ch
        and al,0x77             ; UNMOVED ve siyah piyon isaretini at
        xor al,BLACK|(KING^7)   ; rakip t -> t^3, sah -> 7 en ustte; kendi/cerceve > 7
        cmp al,7
        ja next
        jne move
        cmp al,8                ; sah aliniyor: CF=1, ZF=0 (try donusunde je step tutmasin)
        ret
pawn:   test byte [bx],1        ; piyon: yon tekse capraz
        jnz .d
        test al,al              ; ileri: hedef bos olmali (dolu ise kalan yonler de ileri)
        jnz nsq
        test byte [bx],0x1f     ; +-32: cift adim
        jnz move
        test si,0x60            ; cift adim: satirin 5. ve 6. bitleri esit mi (yatak 1 ya da 6)?
        jpe move                ; (yanlis renkteki 1/6 yatagi hedefi cerceveye duser)
.d:     test al,al              ; capraz dolu: alma denetimi (izinsiz cift adimda AL=0: enp'ye)
        jnz cap
.ep:    cmp di,[enp]            ; capraz bos: yalniz gecerken alma
        jne next
move:   test cl,cl
        jnz cont                ; yanit katmani: yalnizca sah alma
        call try
        je step                 ; rok kuruldu: sahin ikinci adimi (gecersizde ZF=0)
cont:   cmp byte [di],0
        jnz next
        test byte [si],2        ; kayan tas (kale 2, fil 3, vezir 6) bit1'de
        jnz step
next:   inc bx
        dec ah
        jnz dir
nsq:    inc si
        jns sq
        ret                     ; son hucre cerceve: CF=0

key2:   call key            ; dosya harfi; ikinci tus (yatak) asagida dusulerek okunur
key:
%ifdef bios
        mov ah,0
        int 0x16
display:
        pusha
        mov ah,0x0e
        mov bh,0
        int 0x10
        popa
%else
        mov ah,1
        int 0x21                ; yankili oku
%endif
%ifdef bios
        mov [ptab+4],ah         ; terfi: tarama kodu bekci yerine (harf buyuklugune bakmaz)
        and al,0x0f             ; harf -> 1..8 (buyuk/kucuk ayni)
        xchg al,bl              ; AL = onceki tus (dosya), BL = bu tus
        aad 0xf0                ; AL = dosya - 16*AH; AH = rakamin tarama kodu = yatak+1 (1:02 .. 8:09)
        add al,0x8f             ; a1: 1-16*2+0x8f = 0x70
%else
        or al,0x20              ; DOS: kucuk harf (rakamlari etkilemez)
        mov ah,al
        xchg al,[ptab+4]        ; AL = onceki tus; bekci = bu tus (terfi)
        aad 0xf0                ; AL = harf - 16*rakam
        add al,0x1f             ; 'a'-16*'1'+0x1f = 0x70 = a1
%endif
        mov ah,board>>8
        xchg di,ax
        ret
%ifdef boot
        times 510-($-$$) db 0   ; 510'u asarsa nasm burada hata verir
        dw 0xaa55               ; acilis imzasi
%endif
