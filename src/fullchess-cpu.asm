; fullchess-cpu.asm -- FullChess, human (White) vs computer (Black), x86 16-bit (boot or DOS .COM).
;   Same rules as fullchess.asm: legality, castling (all conditions), en passant, promotion choice.
;   The human's moves are fully checked; the computer uses the same generator, so it always
;   plays legal moves. No game-end indicator: if the computer has no move (mate/stalemate) the
;   program spins in an idle loop; if the human has no move, no input is accepted.
;   The computer only counts material: P1 N2 B2 R3 Q4 (table-free aam 5 / aad 2). Rules and
;   evaluation are interleaved: the opponent-reply scan done for legality also collects the
;   opponent's most valuable capture. Promotion: the human's 5th key picks the piece (N knight,
;   R rook, B bishop in either case, any other key a queen; boot: BIOS scan code, DOS: letter);
;   the computer promotes to the piece of the human's last 5th key (normally a queen).
;
;   nasm -f bin [-Dboot] -DPLY=n [-DOR2] [-DSPIN] fullchess-cpu.asm -o x.bin  (without -Dboot: .COM)
;     -DPLY=1 : value of the piece captured
;     -DPLY=2 : captured - opponent's best capture (default)
;     -DPLY=3 : captured - max over replies (their capture - my best capture)
;     -DPLY=4 : 4 plies (fits only as .COM; human move checked at legality depth only)
;     -DOR2   : OR instead of max at the leaf (approximate, shorter)
;     -DSPIN  : single main loop (shorter; every shipped version uses it)
;     -Dboot / -Dbios : as in fullchess.asm
;   Sizes, boot code / .COM (build.sh, all -DSPIN): fullchess-cpu (-DPLY=1) 480/463 (main),
;     cpu2 488/471, cpu2or 484/467, cpu3or 510/496, cpu3 -/500, cpu4or -/513, cpu4 -/517
;     ("-" = does not fit in the boot sector).
;   Piece codes: P1 B2 R3 Q4 N5 K6, colour 0x20, UNMOVED 0x80, frame 0x87 (negative: sentinel).
;   Inline comments below are in Turkish (see docs/DEVLOG.tr.md).
%ifndef PLY
%define PLY 2
%endif
        cpu 286
%ifdef boot
%define bios
ORIGIN  equ 0x7c00              ; BIOS sektoru 0000:7C00'a yukler
%else
ORIGIN  equ 0x100
%endif
        org ORIGIN

PAWN    equ 1
BISHOP  equ 2                   ; bot alfabesi: fil 2, kale 3 -> agirlik = aam 5 / aad 2 ile tur
ROOK    equ 3
QUEEN   equ 4
KNIGHT  equ 5
KING    equ 6
FRONT   equ 0x87                ; cerceve: alt 3 bit 7 (ekranda satir sonu), negatif (bot bekcisi)
BLACK   equ 0x20
UNMOVED equ 0x80                ; hic oynamamis sah/kale (yalniz rokta sorulur, baska yerde silinir)

board   equ 0x7f00
ledger  equ board-0x80          ; tahtanin onundeki 128 bayt: gecerken alma karesi burada
enp     equ ledger+0x08         ; gecerken alma hedefi (yedeklenen bolgede)
%if PLY >= 3
save    equ 0x6007              ; kok seviyesi tamponu (asagidaki duzen)
best    equ save
inp     equ save+1
%else
save    equ 0x8000              ; konum yedegi: yedek 256 bayt, geri koyma 250 bayt
best    equ save+0xfb           ; [puan]: yedek her konumda FRONT (-121) yapar (kaynak: cerceve hucresi)
%endif
%if PLY >= 3
; tampon basi: [best][inp: varis, cikis] (yedekte ledger'in FRONT baytlarindan: best = FRONT),
; geri koyma +6'dan (ledger+6..+255). Adres pozitif ve alt 3 biti 111: yaprak disi
; seviyelerde bp = tampon iken max/or onu bozmaz.
save2   equ 0x6107
best2   equ save2
%else
inp     equ save+0xfc           ; girilen / secilen hamle: [varis][cikis], yedekle 0x8787 olur
%endif
%define LO(x) (((x)-start) & 255)
%define TP   ((((offsets)-start)+ORIGIN)>>8)     ; yon tablolarinin sayfasi (chars her yerde olabilir)

%macro putc 0
%ifdef bios
        call display
%else
        int 0x29
%endif
%endmacro

%macro PTABBLK 0
%ifdef boot
ptab    equ start+1             ; tablo acilis kodunda (start'a bak)
%else
        times (1-(($-start)&7))&7 db 0  ; hiza: LO(ptab) = 1 (mod 8) (xor donusumu icin)
%ifdef bios
ptab:   db 0x13,0x30,0x31       ; terfi, tarama kodlari: R kale, B fil, N at
%else
ptab:   db 'r','b','n'          ; terfi (DOS, ASCII): kale, fil, at
%endif
%endif
initial:                        ; initial[0] = ptab+3: bekci yeri (kurulumdan sonra okunmaz)
        db ROOK|UNMOVED,KNIGHT,BISHOP,QUEEN,KING|UNMOVED,BISHOP,KNIGHT,ROOK|UNMOVED
%endmacro
start:
%ifdef boot
        ; Terfi tablosu acilis kodunun baytlarinda (yalniz bir kez calisir):
        ; B9 [13 30 31] C0 -> ptab = start+1: R kale, B fil, N at; bekci = C0 (acilistan
        ; sonra insanin 5. tusuyla ezilir). LO(ptab) = 1: xor 1 -> 3 kale, 2 fil, 5 at, 4 vezir.
        mov cx,0x3013           ; ayni zamanda dolgu sayisi: 0x7E80..0xAE92
        xor ax,ax               ; BIOS DS/ES/SS:SP icin soz vermiyor: hepsini kur
        mov ds,ax
        mov es,ax
        mov ss,ax
        mov sp,ax               ; yigin 0000:FFFE'den asagi
        mov di,ledger
%else
        mov di,ledger
        mov cx,di
%endif
fill:   push di
        pop ax
        and al,0x88
        jz .z
        mov al,FRONT
.z:     stosb
        loop fill
        mov si,initial
        mov di,board
        mov cl,8
setup:  lodsb
        mov [di+0x70],al
        or al,BLACK
        stosb
        mov byte [di+0x0f],PAWN+BLACK
        inc byte [di+0x5f]
        loop setup
%if PLY >= 3
        inc cx                  ; seviyeler: kok 1, ikinci 2, yaprak 3
%endif

main:
        xor sp,sp               ; tutma cikisi (try) buraya yigin temizlemeden atlar
        mov si,board-8          ; tahtayi ciz (yalnizca buradan cagriliyordu: gomuldu)
.l:
        mov al,[si]
        and al,7
        mov bx,chars
        xlatb
        add al,[si]
        jnc .c                  ; tas/bos: tasma yok; cerceve 0x86+0x87 tasar -> AL = CR
        add si,byte 7
        putc
        mov al,0x0a
.c:     and al,0x7f             ; UNMOVED bitini at
        putc
        inc si
        jns .l
%if PLY >= 3
%if PLY >= 4
        mov cl,1                ; bot: tam derinlik (kok seviyesi 1)
        test ch,ch
        jnz .bt
        mov cl,PLY-1            ; insan: kokun cocugu dogrudan yaprak (yalniz yasallik, hizli)
.bt:
%endif
        mov bp,save             ; kok seviyesinin tamponu (yaprak disi seviyelerde bp = tampon)
        call node               ; yedek (best = FRONT) + 1. gecis
%else
        mov di,si               ; si = save (cizim 0x8000'de bitti)
        mov si,ledger
.bk:    movsw                   ; konum yedegi: 255-256 word (save'in otesi bos bellek, zararsiz)
        inc cl                  ; cl 0 ya da 1'den (tutma cikisi) yine 0'a; ch korunur
        jnz .bk
%endif
%ifdef SPIN                     ; tek dongu: 1. gecis / botun 2. gecisi / insan kontrolu ayni cagri
%if PLY < 3
chk:    call root               ; (bot hamle bulamazsa burada doner: oyun biter, jmp $ gibi)
        test ch,ch
        jnz chk                 ; bot: 2. gecis
%else
chk:    test ch,ch              ; (1. gecis main'deki node'da)
        jnz .b
%endif
%else
%if PLY < 3
        call root               ; 1. gecis: en iyi hamle best/inp'e (insanda da: best max olsun)
%endif
        test ch,ch
        jz inpt
        call root               ; bot: 2. gecis inp'teki hamleyi oynar (esitlik kaydedilmez)
        jc main
inpt:                           ; bot hamle bulamadiysa buraya duser: oyun donar
%endif
        call key2
        mov [inp+2],di          ; cikis
        call key2
        mov [inp],di            ; varis
%ifdef bios
        mov ah,0
        int 0x16
%else
        mov ah,8
        int 0x21
%endif
%ifdef bios
        mov [ptab+3],ah         ; terfi: tarama kodu bekci yerine (R/B/N, gerisi vezir)
%else
        or al,0x20              ; DOS: kucuk harf
        mov [ptab+3],al
%endif
%ifdef SPIN
%if PLY >= 3
.b:     call root           ; donerse oynanmadi (oynanirsa try main'e atlar)
%endif
        jmp chk
%else
        call root
        jc main
        jmp inpt                ; gecersiz giris: best zaten max, 1. gecis gerekmez
%endif

        PTABBLK                 ; boot: yalniz initial (tablo acilis kodunda); DOS: hizali tablo + initial
chars:
        db '.'-0,'P'-1,'B'-2,'R'-3,'Q'-4,'N'-5,'K'-6,(0x0d-FRONT)&255
%ifndef boot
        times ((((($-$$)&255)+31)>>8)|(((($-$$)&255)+252)>>8^1))*((260-(($-$$)&255))&255) db 0 ; DOS: offsets-4..pawnb tek sayfada
%endif
offsets:
        db LO(pawnw),LO(pawnb),LO(bishd),LO(rookd),LO(rookd),LO(disp),LO(rookd)
disp:   db -33,-31,-18,-14,14,18,31,33
rookd:  db 1,-1,16,-16
bishd:  db 15,17,-15,-17
pawnd:
pawnw:  db -15,-17,-16,-32
pawnb:  db 15,17,16,32
        times -((((offsets-4)-start)^((pawnb+3)-start))>>8) db 0 ; offsets-4..pawnb ayni sayfada olmali (xlatb, adim)

rply:   xor ch,BLACK            ; rakip, bir alt katman
        xor bp,bp               ; yaprakta: rakibin en degerli almasi
        inc cx
%if PLY >= 3
%if PLY == 3
        jpe root                ; cl=3 (iki bit, PF=1): yaprak
        mov bp,save2            ; 2. seviye tamponu
        call node               ; yedek + rakibin her cevabi: max(aldigi - benim en iyi almam)
        mov al,[best2]          ; (CF korunur: sah alindiysa ust hamle gecersiz)
%else
        cmp cl,PLY
        je root                 ; yaprak
        mov al,7                ; seviye L tamponu: 0x5F07 + L*0x100 (kok 0x6007)
        mov ah,cl
        add ah,0x5f
        xchg bp,ax
        call node               ; yedek + bu seviyenin her hamlesi
        mov al,[bp]             ; seviyenin best'i (bp seviye boyunca korunur; CF korunur)
%endif
        xchg bp,ax              ; sonuc bp'de; dusuk bayt yeter (puan 8 bit karsilastirilir)
        ret
node:   pusha                   ; bp tamponuna yedekle (best = FRONT), sonra tara
        mov di,bp
        mov si,ledger
        mov cx,128
        rep movsw
        popa
%endif
root:
play:   mov si,board
        mov bh,TP
sq:     mov al,[si]
        and al,0x7f             ; UNMOVED'u at (piyonlarda yok: asagidaki [si] karsilastirmasi temiz)
        xor al,ch
        dec ax
        cmp al,6
        jnc nsq
        cmp byte [si],PAWN+1
        sbb al,0xfb
        mov dh,0x0c
        and dh,al               ; dh = yon sayisi (4 / 8)
        mov bl,LO(offsets-4)
        xlatb
        mov bl,al               ; bx = yon tablosu isaretcisi
dir:    mov di,si
step:   xchg ax,di
        add al,[bx]
        xchg ax,di
        mov al,[di]
        inc ax
        cmp bl,LO(pawnd)
        dec al
        jz empty
        jc cap
        cmp dh,3
        jb nsq
cap:    xor al,ch
        and al,0x7f             ; UNMOVED'u at
        sub al,BLACK            ; AL = rakip tasin turu (sah en buyuk)
        cmp al,KING
        ja next
        jne move
        cmp al,KING+1           ; sah aliniyor: CF=1, ZF=0 (try donusunde je step tutmasin)
        ret
empty:  jc move
        cmp dh,2
        je move
        ja .ep
        test si,0x60            ; cift adim: satirin 5. ve 6. bitleri esit mi (yatak 1 ya da 6)?
        jpe move                ; (yanlis renkteki 1/6 yatagi hedefi cerceveye duser)
.ep:    cmp di,[enp]            ; izinsiz cift adim buraya duser: hedefi enp olamaz
        jne next                ; (bos hedefte AL=0)
move:
        aam 5                   ; tur -> agirlik, tablosuz: (t/5)*2 + t%5
        aad 2                   ; bos 0, P 1, F 2, A 2, K 3, V 4  (bl bozulmuyor)
%if PLY >= 2
%ifdef OR2
        or bp,ax
%else
        cmp ax,bp               ; her katmanda en buyuk alma (yalniz yaprakta kullanilir;
        jle .k                  ; ust katmanlarda bp try'da korunur, onemsiz)
        mov bp,ax
.k:
%endif
%endif
%if PLY == 3
        test cl,cl
        jpe cont                ; cl=3 (kok 1, ikinci 2): yaprak
%elif PLY >= 4
        cmp cl,PLY
        je cont                 ; yaprak
%else
        test cl,cl
        jnz cont                ; yaprak: yalnizca sah alma + en iyi alma
%endif
        call try
        je step                 ; rok kuruldu: sahin ikinci adimi (gecersizde ZF=0)
cont:   mov al,[si]
        cmp byte [di],0
        jnz next
        and al,7
        sub al,2
        cmp al,KNIGHT-2         ; kayan: fil 2, kale 3, vezir 4
        jc step
next:   inc bx
        dec dh
        jnz dir
nsq:    inc si
        jns sq
        ret                     ; son hucre cerceve: CF=0

        ; deneme: hamleyi tam etkileriyle yap, rakip yanitinda sah almasi ara.
        ; Gecerli ve inp'teki hamleyse tahtada birak (CF=1, ana donguye don).
try:    pusha
        mov al,0
        xchg al,[si]
        mov si,enp              ; si artik serbest: enp = [si]
        and al,0x7f             ; tas artik oynamis: UNMOVED silinir
        test al,6               ; piyon mu?
        jnz .np                 ; degilse BX tablo isaretcisi: gecerken alma yok
        mov bx,di
        xor bl,0x10
        cmp di,[si]
        jne .ne
%if PLY < 3
        mov [bx],cl             ; gecerken alinan piyon (try'da cl = 0)
%else
        mov byte [bx],0         ; gecerken alinan piyon
%endif
.ne:    dec dh                  ; dh==1 (cift adim)? dh sonra lea dx ile eziliyor: serbest
        jz .pp                  ; cift adim: BX atlanan kare
        lea dx,[di+0x10]
        test dl,0x60
        jnz .nq
        push di
        mov di,ptab
        mov al,[di+3]           ; bekci = insanin son 5. tusu: bulunamazsa sonda kendisi
.p:     scasb
        jne .p
        xchg ax,di              ; AL = ptab+i+1 (alt bayt)
        xor al,LO(ptab)         ; -> 3 kale, 2 fil, 5 at, 4 vezir (bekci); LO(ptab) = 1 mod 8
        pop di
        or al,ch
.nq:    mov bh,0                ; BX artik kare degil
.pp:
.np:    mov [si],bx
        mov [di],al
        call rply               ; CF=1: gecersiz
        jc .u
        mov si,sp
        mov al,[si+14]          ; puan = aldigimin agirligi: buyuk olan iyi
%if PLY >= 2
        sub ax,bp               ; eksi alt katmanin sonucu
%endif
%if PLY >= 3
        mov di,[si+4]           ; kendi seviyemin tamponu = best (cercevedeki bp)
%else
        mov di,best
%endif
        cmp al,[di]
        jg .rec                 ; daha iyi: kaydet (yalniz 1. taramada olur), tutma
        inc di                  ; DI = inp (best'in hemen ardi)
        cmpsw                   ; girilen / secilen hamle bu mu?
        jne .m
        cmpsw
        jne .m
%if PLY < 3
        jmp main                ; ch zaten rakip; cl = 1 kalir: main'deki yedek dongusu sifirlar
%else
        dec cx                  ; cl: kok seviyesine geri (rply inc etmisti); ch zaten rakip
        jmp main                ; yigin main'de sifirlanir
%endif
.rec:   stosb                   ; yeni en iyi: puan, varis, cikis -> inp
        movsw
        movsw
.m:     clc
%if PLY >= 3
.u:     popa                    ; bp = kendi tamponum (bayraklar korunur)
        pusha
        lea si,[bp+6]           ; geri koyma tamponun +6'sindan
        mov di,ledger+6
%else
.u:     mov si,save
        mov di,ledger
%endif
        mov cx,125
        rep movsw               ; geri koy (best/inp haric)
        popa
        jc .r
        ; rok: sah, dokunulmamis; bu ilk yatay adim gecerliydi. Sahtan kaleye
        ; kadar bos, ucta dokunulmamis kendi kalesi; sah su an sah altinda degil.
        ; Basarida kale gecilen kareye konur, ZF=1 CF=0 doner.
        mov al,KING|UNMOVED
        or al,ch
        cmp al,[si]             ; hic oynamamis kendi sahim mi? (AL = SAH|U|renk kalir)
        jne .r
        mov ah,[bx]             ; AH = bu yonun adimi
        push bx                 ; uretecin yon isaretcisi: .no geri yukler
        mov bx,si
        add bl,ah
        cmp bx,di               ; ilk adim mi?
        jne .no                 ; (bx kare oldu: .no tablo sayfasini geri yukler)
.w:     add bl,ah               ; sayfa icinde yuru (ureteckteki gibi sarar)
        cmp byte [bx],0
        je .w
        xor al,KING^ROOK        ; AL = KALE|U|renk
        cmp al,[bx]             ; hic oynamamis kendi kalem mi?
        jne .no
        pusha
        call rply               ; sah su an sah altinda mi?
        popa
        jc .no
        sub [bx],al             ; kaleyi kaldir; ZF=1 CF=0: ikinci adimi uret
        mov [di],al             ; kale gecilen kareye (rokta sah zaten oynamis olur)
.no:    pop bx
.r:     ret

key2:   call key
        xchg di,ax
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
        and ax,0x0f
        imul bx,ax,-0x10        ; (bp ply3'te seviye tamponu: bozulmasin)
        lea di,[bx+di+board+127]
        ret
%ifdef boot
        times 510-($-$$) db 0   ; 510'u asarsa nasm burada hata verir
        dw 0xaa55               ; acilis imzasi
%endif

