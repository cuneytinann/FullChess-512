; fullchess.asm -- FullChess, two players, x86 16-bit (boot sector or DOS .COM).
;   Rules: all piece moves, legality (no move may leave or put your own king in check),
;   castling with all its conditions, en passant, promotion to queen/knight/bishop/rook,
;   checkmate and stalemate. Atomchess-style move generator; rule logic is our own (README).
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
;   Sizes, boot code / .COM (build.sh): fullchess (-DFIFTY -DFLIP) 492/476 (main version),
;     2p 466/450, 2p50 (-DFIFTY) 481/465, 2pflip (-DFLIP) 477/461,
;     2plight (-DLIGHT) 444/436, 2plightr (-DLIGHT -DREDRAW) 444/436.
;   Piece codes: P1 R2 B3 K4 N5 Q6, colour 0x20, UNMOVED 0x80, frame 0xFF.
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
%define TP   ((((offsets)-start)+ORIGIN)>>8)     ; yon tablolarinin sayfasi (chars her yerde olabilir)

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
        mov cx,di
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
        mov byte [di+0x0f],PAWN+BLACK
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
.ne:    dec dh                  ; dh==1 (cift adim)? dh sonra lea dx ile eziliyor: serbest
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
        and al,7
        mov bx,chars
        xlatb
%ifdef FLIP
        add al,[di]
%else
        add al,[si]
%endif
        jnc .c                  ; tas/bos: tasma yok; cerceve 0x0E+0xFF tasar -> AL = CR
        add si,byte 7
        putc
        mov al,0x0a
.c:     and al,0x7f             ; UNMOVED bitini at
        putc
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
        mov ah,[bx]             ; AH = bu yonun adimi
        push bx                 ; bx = uretecin yon isaretcisi: .no geri yukler
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
try.no: pop bx
try.r:  ret

%ifdef boot
ptab    equ start+1             ; tablo acilis kodunda (yukari bak)
%elifdef bios
ptab:   db 0x13,0x30,0xff,0x31  ; terfi, tarama kodlari: R kale, B fil, (sah yeri), N at
%else
ptab:   db 'r','b',0,'n'        ; terfi: tur-2 sirasiyla (0: sah yeri, hicbir tus|0x20 ona esit olmaz)
%endif
initial:                        ; (DOS: initial[0] = ptab+4 bekci yeri; kurulumdan sonra okunmaz)
        db ROOK|UNMOVED,KNIGHT,BISHOP,QUEEN,KING|UNMOVED,BISHOP,KNIGHT,ROOK|UNMOVED
chars:
        db '.'-0,'P'-1,'R'-2,'B'-3,'K'-4,'N'-5,'Q'-6,(0x0d-FRONT)&255
%ifndef boot
        times ((((($-$$)&255)+31)>>8)|(((($-$$)&255)+252)>>8^1))*((260-(($-$$)&255))&255) db 0 ; DOS: offsets-4..pawnb tek sayfada
%endif
offsets:
        db LO(pawnw),LO(pawnb),LO(rookd),LO(bishd),LO(rookd),LO(disp),LO(rookd)
disp:   db -33,-31,-18,-14,14,18,31,33
rookd:  db 1,-1,16,-16
bishd:  db 15,17,-15,-17
pawnd:
pawnw:  db -15,-17,-16,-32
pawnb:  db 15,17,16,32
        times -((((offsets-4)-start)^((pawnb+3)-start))>>8) db 0 ; offsets-4..pawnb ayni sayfada olmali (xlatb, adim)

rply:   xor ch,BLACK            ; rakip, yanit katmani
        inc cx                  ; cl her rply cagrisinda 0 -> 1 (ch uzerine tasma yok)
root:
%ifndef LIGHT
        xor bp,bp               ; gecerli hamle sayaci
%endif
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
        mov bl,al               ; bx = yon tablosu isaretcisi (dl bos)
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
        xor al,BLACK|(KING^7)   ; rakip t -> t^3, sah -> 7 en ustte; kendi/cerceve > 7
        cmp al,7
        ja next
        jne move
        cmp al,8                ; sah aliniyor: CF=1, ZF=0 (try donusunde je step tutmasin)
        ret
empty:  jc move
        cmp dh,2
        je move
        ja .ep
        test si,0x60            ; cift adim: satirin 5. ve 6. bitleri esit mi (yatak 1 ya da 6)?
        jpe move                ; (yanlis renkteki 1/6 yatagi hedefi cerceveye duser)
.ep:    cmp di,[enp]            ; izinsiz cift adim buraya duser: hedefi enp olamaz
        jne next                ; (bos hedefte AL=0)
move:   test cl,cl
        jnz cont                ; yanit katmani: yalnizca sah alma
        call try
        je step                 ; rok kuruldu: sahin ikinci adimi (gecersizde ZF=0)
cont:   cmp byte [di],0
        jnz next
        test byte [si],2        ; kayan tas (kale 2, fil 3, vezir 6) bit1'de
        jnz step
next:   inc bx
        dec dh
        jnz dir
nsq:    inc si
        jns sq
        ret                     ; son hucre cerceve: CF=0

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
%ifdef bios
        mov [ptab+4],ah         ; terfi: tarama kodu bekci yerine (harf buyuklugune bakmaz)
%else
        or al,0x20              ; DOS: kucuk harf (koordinatlari etkilemez: alt 4 bit)
        mov [ptab+4],al
%endif
        and ax,0x0f
        imul bp,ax,-0x10
        lea di,[bp+di+board+127]
        ret
%ifdef boot
        times 510-($-$$) db 0   ; 510'u asarsa nasm burada hata verir
        dw 0xaa55               ; acilis imzasi
%endif
