; fullchess.asm -- FullChess, two players, x86 16-bit (boot sector or DOS .COM).
;   Rules: all piece moves, legality (no move may leave or put your own king in check),
;   castling with all its conditions, en passant, promotion to queen/knight/bishop/rook,
;   checkmate and stalemate. Atomchess-style move generator; rule logic is our own (README).
;
;   nasm -f bin [-Dboot] [options] fullchess.asm -o x.bin     (without -Dboot: DOS .COM)
;     -Dboot   : org 0x7C00, BIOS I/O, sets up segments and stack, halts at game end (jmp $),
;                padded to 510 bytes + 0x55AA signature (nasm errors out if code exceeds 510)
;     -Dbios   : .COM, but I/O through BIOS (int 10h/16h)
;     -DLIGHT  : no game-end indicator; at mate/stalemate no input is accepted (game freezes)
;     -DREDRAW : (only with -DLIGHT) board is redrawn after every input
;     -DFIFTY  : (without LIGHT) automatic draw after 50 moves = 100 plies; -DPLIES=150: 75 moves
;     -DFLIP   : board rotates 180 degrees when Black is to move (input stays absolute)
;   Sizes, boot code / .COM (build.sh): fullchess (-DFIFTY -DFLIP) 510/488 (main version),
;     2p 479/457, 2p50 (-DFIFTY) 499/477, 2pflip (-DFLIP) 490/468,
;     2plight (-DLIGHT) 457/437, 2plightr (-DLIGHT -DREDRAW) 455/435.
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
hm      equ ledger+0x0a         ; FIFTY: yarim hamle sayaci, FRONT'tan sayar (yedeklenen bolgede)
%ifndef PLIES
PLIES   equ 100                 ; 50 hamle = 100 yarim hamle (FideLite L2'nin otomatik 75'i: -DPLIES=150)
%endif
save    equ 0x8000              ; konum yedegi: yedek 256 bayt, geri koyma 250 bayt
promo   equ save+0xfb           ; terfi tasi: inp'in hemen onunde -> tek stosb+stosw+stosw zinciri
inp     equ promo+1             ; = save+0xfc ; girilen hamle: [varis][cikis]
%define LO(x) (((x)-start) & 255)
%define TP   ((((chars)-start)+ORIGIN)>>8)

%macro putc 0
%ifdef bios
        call display
%else
        int 0x29
%endif
%endmacro

start:
%ifdef boot
        xor ax,ax               ; BIOS DS/ES/SS:SP icin soz vermiyor: hepsini kur
        mov ds,ax
        mov es,ax
        mov ss,ax
        mov sp,ax               ; yigin 0000:FFFE'den asagi; dolgu 0xFD00'de biter
%endif
        mov di,ledger
        mov cx,di
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

main:
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
        and al,0x7f             ; UNMOVED bitini at
        cmp al,0x0d
        jnz .c
        add si,byte 7
        putc
        mov al,0x0a
.c:     putc
        inc si
        jns .l
        pusha
        mov si,ledger
        mov di,save
        mov cx,128
        rep movsw               ; konum yedegi
        popa
%ifndef REDRAW
chk:    call root               ; CF=1: hamle oynandi, sira degisti
        jc main
%endif
%ifndef LIGHT
        or bp,bp                ; gecerli hamle sayisi
        jz over
%ifdef FIFTY
        cmp byte [si+hm-ledger],(FRONT+PLIES)&255  ; si = save (tarama bitti): sayacin yedegi
        je over.d               ; esitlikte CF=0 -> '=' (mat onceliklidir: yukarida bakildi)
%endif
%endif                          ; LIGHT: sayac yok; hamle kalmadiysa hicbir giris kabul edilmez
        call key2
        call key2
        push di                 ; varis karesini sakla (key DI'yi bozar)
        call key                ; 5. tus (yankili): AL = tus & 15, AH = 0
        imul ax,ax,0x4b         ; terfi tusu -> tur: Enter/1 vezir, 2 at, 3 fil, 4 kale
        or al,0x9f              ; her bayt -> 9F/BF/DF/FF ...
        aam 7                   ; ... -> at/kale/vezir/fil: HER tus gecerli bir tas (kaba kuvvetle bulundu)
        mov di,promo
        stosb                   ; [promo]=al, di->inp
        pop ax
        stosw                   ; varis
        xchg ax,si
        stosw                   ; cikis
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
        ret
%endif
%endif

initial:
        db ROOK|UNMOVED,KNIGHT,BISHOP,QUEEN,KING|UNMOVED,BISHOP,KNIGHT,ROOK|UNMOVED
chars:
        db '.'-0,'P'-1,'R'-2,'B'-3,'K'-4,'N'-5,'Q'-6,(0x0d-FRONT)&255
offsets:
        db LO(pawnw),LO(pawnb),LO(rookd),LO(bishd),LO(rookd),LO(disp),LO(rookd)
disp:   db -33,-31,-18,-14,14,18,31,33
rookd:  db 1,-1,16,-16
bishd:  db 15,17,-15,-17
pawnd:
pawnw:  db -15,-17,-16,-32
pawnb:  db 15,17,16,32

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
        mov ah,0x0c
        and ah,al
        mov bl,LO(offsets-4)
        xlatb
        xchg dx,ax
dir:    mov di,si
step:   mov bl,dl
        xchg ax,di
        add al,[bx]
        xchg ax,di
        mov al,[di]
        inc ax
        cmp dl,LO(pawnd)
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
        stc                     ; sah aliniyor
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
        jc cont                 ; gecersiz
        je step                 ; rok kuruldu: sahin ikinci adimi
cont:   cmp byte [di],0
        jnz next
        test byte [si],2        ; kayan tas (kale 2, fil 3, vezir 6) bit1'de
        jnz step
next:   inc dx
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
        and al,0x7f             ; tas artik oynamis: UNMOVED silinir
        test al,6               ; piyon mu?
        jnz .np                 ; degilse BX tablo isaretcisi: gecerken alma yok
        mov bx,di
        xor bl,0x10
        cmp di,[enp]
        jne .ne
        mov byte [bx],0         ; gecerken alinan piyon
.ne:    dec dh                  ; dh==1 (cift adim)? dh sonra lea dx ile eziliyor: serbest
        jz .pp                  ; cift adim: BX atlanan kare
        lea dx,[di+0x10]
        test dl,0x60
        jnz .nq
        mov al,[promo]          ; terfi tasi
        or al,ch
.nq:    mov bh,0                ; BX artik kare degil
.pp:
%ifdef FIFTY
        stc                     ; piyon hamlesi (tas olmayanlar .np'ye CF=0 ile gelir: test)
%endif
.np:    mov [enp],bx
%ifdef FIFTY
        xchg [di],al            ; al = alinan tas (0: bos)
        adc al,0                ; alma ya da piyon -> sifir degil
        jz .i
        mov byte [hm],FRONT-1   ; sifirla (asagidaki inc ile FRONT)
.i:     inc byte [hm]
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
        sub sp,byte -18         ; pusha(16)+donus(2) at; kayitlari geri koyma (main sifirlar)
        dec cx                  ; cl: 1->0 (rply inc etmisti); ch zaten rakip; SP<0xFFEE: CF=1
        ret
.m:     clc
.u:     mov si,save
        mov di,ledger
        mov cx,125
        rep movsw               ; geri koy (promo/inp haric)
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
.no:    mov bh,TP               ; BX yine tablo sayfasi
.r:     ret

key2:   xchg si,di
        call key
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
        imul bp,ax,-0x10
        lea di,[bp+di+board+127]
        ret
%ifdef boot
        times 510-($-$$) db 0   ; 510'u asarsa nasm burada hata verir
        dw 0xaa55               ; acilis imzasi
%endif
