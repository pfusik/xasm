	IDEAL
	P386
	MODEL	TINY
	CODESEG
	ORG	100h
	include	'fox.mak'
smartio	=	1

start:
	db	2048 dup(0)	;compack

o_a	=	1
o_b	=	2
o_c	=	4
o_d	=	8
o_f	=	10h
o_i	=	20h
o_l	=	40h
o_n	=	80h
o_x	=	100h

MACRO	topt	_op
	testflag dx, _op
	ENDM

	mov	si, 81h
	mov	bx, 0ff00h	;bh=attr mask, bl=attr set
	xor	dx, dx		;dx=options

gsw1:	lodsb
	cmp	al, ' '
	je	gsw1
	cmp	al, 9
	je	gsw1
	cmp	al, 0dh
	je	gswx
	cmp	al, '/'
	je	gsw2
	cmp	al, '-'
	je	gsw2
usage:	mov	dx, offset usgtxt
panic:	print
	int	20h

	smartdisk

rdpage:	mov	cx, 100h
	fread
	cmp	ax, cx
	jb	_derr
	ret

rdnum:	lodsb
	cmp	al, ':'
	jne	usage
	lodsw
	sub	ax, '00'
	cmp	al, 10
	jae	usage
	cmp	ah, 10
	jae	rdnum1
	xchg	al, ah
	aad		;al:=10*ah+al
	cmp	al, 15
	ja	usage
	ret
rdnum1:	dec	si
	ret

gsw2:	lodsb
	and	al, 0dfh
	mov	di, offset swilet
	mov	cx, 9
	repne	scasb
	jne	usage
	bts	dx, cx
	jc	usage
	cmp	al, 'B'
	je	sw_b
	cmp	al, 'C'
	je	sw_c
	cmp	al, 'F'
	je	sw_f
	jmp	gsw1

sw_b:	call	rdnum
	shl	al, 4
	and	bh, 0fh
	or	bl, al
	jmp	gsw1

sw_c:	call	rdnum
	and	bh, 0f0h
	or	bl, al
	jmp	gsw1

sw_f:	cmp	[byte si], ':'
	jne	usage
	mov	di, offset fname-1
swf1:	movsb
	cmp	[byte si], ' '
	je	swf2
	cmp	[byte si], 9
	je	swf2
	cmp	[byte si], 0dh
	jne	swf1
swf2:	pusha
	mov	bx, di
	mov	cx, di
	sub	cx, offset fname
	je	short jusage
adex1:	dec	bx
	cmp	[byte bx], '.'
	je	adexn
	cmp	[byte bx], '\'
	loopne	adex1
adex2:	mov	eax, 'TNF.'
	stosd
adexn:	mov	[byte di], 0

	fopen	fname
	mov	dx, offset font+100h	;digits
	call	rdpage
	mov	dx, offset font+200h	;letters
	call	rdpage
	mov	dx, offset font		;controls
	call	rdpage
	mov	dx, offset font+300h	;low letters
	call	rdpage
	fclose
	popa
	jmp	gsw1

gswx:	test	dx, dx
	jz	jusage

	topt	o_a	;obsluz opcje a
	jz	atrok
	setflag	dx, o_n+o_l
	topt	o_b
	jnz	anob
	and	bx, 0f0fh
	or	bl, 10h
anob:	topt	o_c
	jnz	anoc
	and	bx, 0f0f0h
	or	bl, 7
anoc:	topt	o_d+o_f+o_x
	jnz	atrok
	setflag	dx, o_x
atrok:

	mov	ax, dx	;sprawdz opcje fontu
	and	ax, o_d+o_f+o_x
	jz	nofnt	
	bsf	cx, ax	;dozwolona max 1 z opcji d,f,x
	btr	ax, cx
	test	ax, ax
	jz	fntok
jusage:	jmp	usage
nofnt:	topt	o_l	;jezeli l i zadna z d,f,x, to ustaw d
	jz	fntok
	setflag	dx, o_d
fntok:	topt	o_i
	jz	noinv0
	topt	o_f+o_x	;i tylko razem z f lub x
	jz	jusage
noinv0:

	push	bx

; inicjuj tryb tekstowy
	topt	o_n
	jz	noini
	push	dx
	mov	ax, 3
	int	10h
	pop	dx
noini:

; wczytaj font domyslny
	topt	o_d+o_f+o_x
	jz	nodef
	mov	ax, 1112h
	topt	o_l
	jnz	def50
	mov	al, 14h
def50:	push	dx
	xor	bl, bl
	int	10h
	pop	dx
nodef:

; wczytaj font uzytkownika
	topt	o_f+o_x
	jz	nocust

; ustaw odpowiedni font
	mov	cx, 128
	topt	o_i
	jz	noinv
; inwertuj znaki 0-127 na 128-255
	mov	si, offset font
	mov	di, offset ifont
	mov	cx, 1024
mkinv:	lodsb
	not	al
	stosb
	loop	mkinv
	mov	cx, 256
noinv:	mov	bp, offset font
	mov	bx, 800h
	topt	o_l
	jnz	nodbl
; rob font o podwojonej wysokosci
	mov	si, offset font
	mov	di, offset dfont
	push	cx
	mov	cx, 2048
mkdbl:	lodsb
	mov	ah, al
	stosw
	loop	mkdbl
	pop	cx
	mov	bp, offset dfont
	mov	bh, 16
nodbl:	push	dx
	xor	dx, dx
	mov	ax, 1110h
	int	10h
	pop	dx
nocust:

; jezeli przelaczylismy 50->25 to skorygowac polozenie kursora
	topt	o_l
	jnz	nococu
	topt	o_d+o_f+o_x
	jz	nococu
	xor	bh, bh
	mov	ah, 3
	int	10h	;wez pozycje kursora
	sub	dh, 25
	jb	nococu
	xor	bh, bh
	mov	ah, 2
	int	10h	;ustaw kursor
	mov	ax, 0b800h	;przesuwa dolna polowke ekranu do gory
	mov	ds, ax
	mov	es, ax
	mov	si, 2*80*25
	xor	di, di
	mov	cx, si
	rep	movsb
	mov	ax, [di]	;czysci dolna polowke
	mov	al, ' '
	mov	cx, 80*25
	rep	stosw
	push	cs
	pop	ds
	push	cs
	pop	ds

nococu:
; ustaw kolory
	pop	bx
	cmp	bh, 0ffh
	je	nocol
	push	0b800h
	pop	es
	xor	di, di
	mov	cx, 80*50
cls:	inc	di
	and	[es:di], bh
	or	[es:di], bl
	inc	di
	loop	cls
nocol:	ret

swilet	db	'XNLIFDCBA'
usgtxt	db	'GR0 version 1.1 by Fox/Taquart',eol
	db	'Customizes DOS screen.',eol
	db	'Available options:',eol
	db	'/a       Set Atari scheme = /b:1 /c:7 /n /l /x',eol
	db	'/b:nn    Set background color 0-15',eol
	db	'/c:nn    Set foreground color 0-15',eol
	db	'/d       Set default PC font',eol
	db	'/f:fname Set external Atari font',eol
	db	'/i       Set characters 128-255 to inverse',eol
	db	'/l       Select 50 lines font',eol
	db	'/n       Initialize text mode (clears screen)',eol
	db	'/x       Set Atari built-in font',eot
	smarterr

font	db	0,54,127,127,62,28,8,0,24,24,24,31,31,24,24,24,3
	db	3,3,3,3,3,3,3,24,24,24,248,248,0,0,0,24,24,24
	db	248,248,24,24,24,0,0,0,248,248,24,24,24,3,7,14,28,56
	db	112,224,192,192,224,112,56,28,14,7,3,1,3,7,15,31,63,127
	db	255,0,0,0,0,15,15,15,15,128,192,224,240,248,252,254,255,15
	db	15,15,15,0,0,0,0,240,240,240,240,0,0,0,0,255,255,0
	db	0,0,0,0,0,0,0,0,0,0,0,255,255,0,0,0,0,240
	db	240,240,240,0,28,28,119,119,8,28,0,0,0,0,31,31,24,24
	db	24,0,0,0,255,255,0,0,0,24,24,24,255,255,24,24,24,0
	db	0,60,126,126,126,60,0,0,0,0,0,255,255,255,255,192,192,192
	db	192,192,192,192,192,0,0,0,255,255,24,24,24,24,24,24,255,255
	db	0,0,0,240,240,240,240,240,240,240,240,24,24,24,31,31,0,0
	db	0,120,96,120,96,126,24,30,0,0,24,60,126,24,24,24,0,0
	db	24,24,24,126,60,24,0,0,24,48,126,48,24,0,0,0,24,12
	db	126,12,24,0,0,0,0,0,0,0,0,0,0,0,24,24,24,24
	db	0,24,0,0,102,102,102,0,0,0,0,0,102,255,102,102,255,102
	db	0,24,62,96,60,6,124,24,0,0,102,108,24,48,102,70,0,28
	db	54,28,56,111,102,59,0,0,24,24,24,0,0,0,0,0,14,28
	db	24,24,28,14,0,0,112,56,24,24,56,112,0,0,102,60,255,60
	db	102,0,0,0,24,24,126,24,24,0,0,0,0,0,0,0,24,24
	db	48,0,0,0,126,0,0,0,0,0,0,0,0,0,24,24,0,0
	db	6,12,24,48,96,64,0,0,60,102,110,118,102,60,0,0,24,56
	db	24,24,24,126,0,0,60,102,12,24,48,126,0,0,126,12,24,12
	db	102,60,0,0,12,28,60,108,126,12,0,0,126,96,124,6,102,60
	db	0,0,60,96,124,102,102,60,0,0,126,6,12,24,48,48,0,0
	db	60,102,60,102,102,60,0,0,60,102,62,6,12,56,0,0,0,24
	db	24,0,24,24,0,0,0,24,24,0,24,24,48,6,12,24,48,24
	db	12,6,0,0,0,126,0,0,126,0,0,96,48,24,12,24,48,96
	db	0,0,60,102,12,24,0,24,0,0,60,102,110,110,96,62,0,0
	db	24,60,102,102,126,102,0,0,124,102,124,102,102,124,0,0,60,102
	db	96,96,102,60,0,0,120,108,102,102,108,120,0,0,126,96,124,96
	db	96,126,0,0,126,96,124,96,96,96,0,0,62,96,96,110,102,62
	db	0,0,102,102,126,102,102,102,0,0,126,24,24,24,24,126,0,0
	db	6,6,6,6,102,60,0,0,102,108,120,120,108,102,0,0,96,96
	db	96,96,96,126,0,0,99,119,127,107,99,99,0,0,102,118,126,126
	db	110,102,0,0,60,102,102,102,102,60,0,0,124,102,102,124,96,96
	db	0,0,60,102,102,102,108,54,0,0,124,102,102,124,108,102,0,0
	db	60,96,60,6,6,60,0,0,126,24,24,24,24,24,0,0,102,102
	db	102,102,102,126,0,0,102,102,102,102,60,24,0,0,99,99,107,127
	db	119,99,0,0,102,102,60,60,102,102,0,0,102,102,60,24,24,24
	db	0,0,126,12,24,48,96,126,0,0,30,24,24,24,24,30,0,0
	db	64,96,48,24,12,6,0,0,120,24,24,24,24,120,0,0,8,28
	db	54,99,0,0,0,0,0,0,0,0,0,255,0,0,24,60,126,126
	db	60,24,0,0,0,60,6,62,102,62,0,0,96,96,124,102,102,124
	db	0,0,0,60,96,96,96,60,0,0,6,6,62,102,102,62,0,0
	db	0,60,102,126,96,60,0,0,14,24,62,24,24,24,0,0,0,62
	db	102,102,62,6,124,0,96,96,124,102,102,102,0,0,24,0,56,24
	db	24,60,0,0,6,0,6,6,6,6,60,0,96,96,108,120,108,102
	db	0,0,56,24,24,24,24,60,0,0,0,102,127,127,107,99,0,0
	db	0,124,102,102,102,102,0,0,0,60,102,102,102,60,0,0,0,124
	db	102,102,124,96,96,0,0,62,102,102,62,6,6,0,0,124,102,96
	db	96,96,0,0,0,62,96,60,6,124,0,0,24,126,24,24,24,14
	db	0,0,0,102,102,102,102,62,0,0,0,102,102,102,60,24,0,0
	db	0,99,107,127,62,54,0,0,0,102,60,24,60,102,0,0,0,102
	db	102,102,62,12,120,0,0,126,12,24,48,126,0,0,24,60,126,126
	db	24,60,0,24,24,24,24,24,24,24,24,0,126,120,124,110,102,6
	db	0,8,24,56,120,56,24,8,0,16,24,28,30,28,24,16,0
fname:
ifont	db	1024 dup(?)

dfont	db	4096 dup(?)

	ENDS
	END	start