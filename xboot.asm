; ><-B00T IV b. Fox

	IDEAL
	P386
	MODEL	TINY
	CODESEG
zero	db	100h dup(?)

blen	=	60*1024

m_pro	=	1	; /p switch
m_wild	=	2	; obx has wild char
m_errs	=	4	; error/warning occured while current file
m_donta	=	8	; don't change output ext to atr

ffnam	=	80h+1eh

eol	equ	13,10
eot	equ	13,10,'$'

MACRO	lda	_rg	;shorter than 'mov (e)ax, _rg'
_rge	SUBSTR	<_rg>, 1, 1
IFIDNI	_rge, <e>
	xchg	eax, _rg
ELSE
	xchg	ax, _rg
ENDIF
	ENDM

MACRO	sta	_rg	;shorter than 'mov _rg, (e)ax'
_rge	SUBSTR	<_rg>, 1, 1
IFIDNI	_rge, <e>
	xchg	_rg, eax
ELSE
	xchg	_rg, ax
ENDIF
	ENDM

MACRO	dos	_func
IFNB	<_func>
IF	_func and 0ff00h
	mov	ax, _func
ELSE
	mov	ah, _func
ENDIF
ENDIF
	int	21h
	ENDM

MACRO	file	_func
IFNB	<_func>
IF	_func and 0ff00h
	mov	ax, _func
ELSE
	mov	ah, _func
ENDIF
ENDIF
	call	xdisk
	ENDM

MACRO	jfile	_func
IFNB	<_func>
IF	_func and 0ff00h
	mov	ax, _func
ELSE
	mov	ah, _func
ENDIF
ENDIF
	jmp	xdisk
	ENDM

MACRO	print	_text
IFNB	<_text>
	mov	dx, offset _text
ENDIF
	dos	9
	ENDM


start:
	db	1536 dup(0)	; COMpack sux
	mov	[spt], sp
	print	hello

	mov	si, 81h		; pobierz argumenty
	mov	di, offset obxnam
	mov	ch, -1

arg1:	lodsb
	cmp	al, ' '
	je	arg1		; spacje omijamy
	cmp	al, '/'
	jne	nswit
	lodsb			; '/' - switch
	and	al, 0dfh
	cmp	al, 'P'
	jne	usg
	or	[flags], m_pro	; '/P'
	jmp	arg1
nswit:	cmp	al, 0dh
	je	argx
	cmp	di, offset atrnam
	ja	usg		; byly juz dwie nazwy

spath:	mov	dl, -1		; dolaczaj rozsz.
	cmp	di, offset atrnam
	jnb	snam1
	and	[flags], not m_wild
	mov	[onam], di	; onam - adres nazwy PLIKU .obx
snam1:	cmp	di, offset atrnam
	ja	snam2
	cmp	al, '*'		; w obx sprawdzaj wildy
	je	wildch
	cmp	al, '?'
	jne	snam2
wildch:	or	[flags], m_wild
snam2:	cmp	al, '.'
	jne	npoint
	xor	dl, dl		; jest rozszerzenie - nie dolaczaj .obx
npoint:	stosb			; przepisz nazwe
	lodsb
	cmp	al, ' '		; spacja lub eol konczy
	je	snamx
	cmp	al, 0dh
	je	snamx
	cmp	al, '/'
	je	snamx		; '/' tez konczy
	cmp	[byte di-1], '\'
	je	spath
	jmp	snam1

usg:	print	usgtxt
	dos	4c03h

snamx:	mov	eax, 'XBO.'
	cmp	di, offset atrnam
	jb	adobx
	test	[flags], m_wild
	jz	atrnwl
	mov	al, '\'
	cmp	al, [di-1]
	je	panam
	stosb
panam:	mov	[anam], di
	jmp	nadext
atrnwl:	test	dl, dl
	jz	adatr		; jest podane rozszerzenie -
	or	[flags], m_donta	; nie zmieniaj go na atr
adatr:	mov	eax, 'RTA.'
adobx:	test	dl, dl
	jz	nadext
	stosd
nadext:	xor	al, al
	stosb
	mov	[nfin], di
	dec	si
	cmp	di, offset atrnam
	mov	di, offset atrnam
	jb	jarg1
	inc	di
jarg1:	jmp	arg1

argx:	cmp	di, offset atrnam
	jb	usg		; nie ma nazwy
	ja	jesatr
	mov	cx, [nfin]
	test	[flags], m_wild
	jz	nowil1		; jak jeden plik, to przepiszemy cala nazwe
	mov	cx, [onam]	; jak wiele, to tylko sciezke
nowil1:	mov	si, offset obxnam
	sub	cx, si
	rep	movsb
	mov	[nfin], di
jesatr:

	test	[flags], m_wild
	jz	nowild
	xor	cx, cx
	mov	dx, offset obxnam
	mov	ah, 4eh		; jak wiele, to szukamy

main1:	and	[flags], not m_errs
	mov	[ohand], 0
	mov	[ahand], 0
	mov	[len], lodlen+endlen
	dos
	jc	fin
	mov	si, 80h+1eh
	mov	di, [anam]
	mov	bx, [onam]
mona1:	lodsb
	stosb
	mov	[bx], al
	inc	bx
	test	al, al
	jnz	mona1
	mov	[nfin], di

nowild:	mov	si, offset obxnam
	call	printz			; file.obx
	mov	dx, offset obxnam
	mov	bp, offset e_open
	file	3d00h			; open for reading
	mov	[ohand], ax
	call	xreadh
	jb	enate
	cmp	[head], -1
	jne	enate

	mov	dx, offset head
	mov	cx, 4
	call	xread
	jnb	nenate
enate:	mov	dx, offset e_nota
	jmp	error
nenate:
	mov	ax, [head]
	mov	[l1runl], al
	mov	[l2runl], al
	mov	[l1runh], ah
	mov	[l2runh], ah

	print	arrow			; ->
	test	[flags], m_donta
	jnz	jatrex
	mov	di, [nfin]
	mov	si, di
cetatr:	dec	si
	cmp	[byte si], '\'
	je	cetafn
	cmp	[byte si], '.'
	jne	cetatr
	mov	di, si
cetafn:	mov	eax, 'RTA.'
	stosd
	mov	[byte di], 0
jatrex:
	mov	si, offset atrnam
	call	printz			; file.atr
	xor	cx, cx
	mov	dx, offset atrnam
	mov	bp, offset e_creat
	file	3ch			; create
	mov	[ahand], ax
	print	kropki			; ...

	mov	cx, beglen
	mov	dx, offset begin
	call	xwrite
	mov	cx, lodlen
	mov	dx, offset stdlod
	test	[flags], m_pro
	jz	stlo
	mov	dx, offset prolod
stlo:	call	xwrite
	jmp	firs

skff:
	call	xreadh
	jb	chtrun
	cmp	[head], -1
	je	skff
	mov	dx, offset head+2
	call	xread2
	jb	trunca

firs:	mov	cx, [head+2]
	sub	cx, [head]
	jb	einva
	inc	cx
	cmp	cx, blen
	ja	einva
	mov	dx, offset blok
	call	xread
	jb	trunc
	call	xwrihd
	jmp	skff

einva:	mov	dx, offset e_head
	jmp	error

chtrun:	test	ax, ax
	jnz	trunca
	jmp	finfil

trunc:	test	ax, ax
	jz	finfil
	dec	ax
	push	ax
	add	ax, [head]
	mov	[head+2], ax
	pop	ax
	call	xwrihd

trunca:	mov	dx, offset w_trunc
	call	warni
finfil:	mov	dx, offset endseq1
	test	[flags], m_pro
	jz	endst
	mov	dx, offset endseq2
endst:	mov	cx, endlen
	call	xwrite
	mov	cx, 40h
	xor	ax, ax
	mov	di, offset head
	rep	stosw
	sta	cx
	sub	cl, [byte len]
	and	ecx, 7fh
	jz	fuls
	call	xwrith
fuls:	xor	cx, cx		; seek back to para's atr header field
	mov	dx, 2
	mov	bp, offset e_write
	file	4200h
	shr	[len], 4
	mov	cx, 2
	mov	dx, offset len
	call	xwrite

shut:	mov	bx, [ahand]
	mov	bp, offset e_write
	call	xclose
	mov	bx, [ohand]
	mov	bp, offset e_read
	call	xclose

	test	[flags], m_errs
	jnz	nook
	print	oktxt
nook:	print	eoltxt
	test	[flags], m_wild
	jz	fin
	mov	ah, 4fh
	jmp	main1

fin:	mov	ax, [exitcod]
	dos

xdisk:	push	bp
	dos
	pop	dx
	jnc	rts
error:	mov	sp, [spt]
	mov	[byte exitcod], 2
	or	[flags], m_errs
	print
	jmp	shut

warni:	cmp	[byte exitcod], 1
	jae	nwacod
	mov	[byte exitcod], 1
nwacod:	or	[flags], m_errs
	print
	ret

xreadh:	mov	dx, offset head
xread2:	mov	cx, 2
xread:	mov	bx, [ohand]
	mov	bp, offset e_read
	file	3fh
	cmp	ax, cx
rts:	ret

xwrihd:	add	ax, 4
	movzx	ecx, ax
	mov	ax, [head]
	mov	dx, [head+2]
	test	[flags], m_pro
	jnz	chkpro
	cmp	ah, 8
	jae	chkst1
	cmp	dh, 7
	jae	ememc
chkst1:	cmp	dh, 0c0h
	jb	xwrith
	cmp	dh, 0d0h
	jb	eproc
	cmp	ah, 0d8h
	jb	xwrith
eproc:	mov	dx, offset w_prof
	jmp	xwwarn

chkpro:	cmp	ah, 5
	jae	xwrith
	cmp	dh, 4
	jb	xwrith

ememc:	mov	dx, offset w_mem
xwwarn:	push	ecx
	call	warni
	pop	ecx

xwrith:	mov	dx, offset head
xwritl:	add	[len], ecx
xwrite:	mov	bx, [ahand]
	mov	bp, offset e_write
	jfile	40h

xclose:	test	bx, bx
	jz	rts
	jfile	3eh

pnam1:	sta	dx
	dos	2
printz:	lodsb
	test	al, al
	jnz	pnam1
	ret

hello	db	'X-BOOT 4.0 by Fox/Taquart',eot
usgtxt	db	'XBOOT [/p] obxfile [atrfile]',eol
	db	'  Convert single Atari 8-bit executable into .ATR disk image.',eol
	db	'XBOOT [/p] obxfiles [atrpath]',eol
	db	'  Convert many files - wildcards allowed.',eol
	db	'/p switch',eol
	db	'  Write professional loader rather than standard.'
eoltxt	db	eot
arrow	db	' -> $'
kropki	db	' ... $'
oktxt	db	'OK$'
w_mem	db	eol,'  WARNING: Memory conflict$'
w_prof	db	eol,'  WARNING: Professional loader needed$'
w_trunc	db	eol,'  WARNING: File is truncated$'
e_nota	db	eol,'  ERROR: Not Atari executable$'
e_head	db	eol,'  ERROR: Invalid header$'
e_open	db	eol,'  ERROR: Can''t open file$'
e_read	db	eol,'  ERROR: Disk read error$'
e_creat	db	eol,'  ERROR: Can''t create file$'
e_write	db	eol,'  ERROR: Disk write error$'

; ATR Header
begin	dw	296h,0,80h,5 dup(0)
beglen	=	$-begin

; Loader #1 (std)
stdlod	db	0,1,128,7,119,228,160,215,185,27,7,145,88,200,192,226,144
	db	246,169
l1runl	db	168,141,224,2,169
l1runh	db	7,141,225,2,169,7,141,5,3,169,255
	db	141,1,211,173,56,96,169,7,141,227,2,72,169,168,141,226,2,72
	db	162,251,149,72,232,134,67,238,210,7,16,16,238,10,3,208,3,238
	db	11,3,32,83,228,48,217,14,210,7,173,127,7,166,67,208,223,129
	db	68,230,68,208,2,230,69,165,70,197,68,165,71,229,69,176,210,169
	db	3,141,15,210,108,226,2,44,111,97,100,105,110,103,14,14,14,0
	db	52,46,48
lodlen	=	$-stdlod

; Ending Header for loader #1
endseq1	db	240,7,240,7,224
endlen	=	$-endseq1

; Loader #2 (rom)
prolod	db	0,1,128,4,119,228,169,0,141,47,2,169,82,141,200,2,165
	db	20,197,20,240,252,169
l2runl	db	162,141,224,2,169
l2runh	db	4,141,225,2,173,56,96
	db	169,4,141,227,2,72,169,162,141,226,2,72,162,251,149,72,232,134
	db	67,238,220,4,16,32,238,10,3,208,3,238,11,3,169,255,141,1
	db	211,78,14,212,88,32,83,228,48,208,120,238,14,212,206,1,211,14
	db	220,4,173,127,4,166,67,208,207,129,68,230,68,208,2,230,69,165
	db	70,197,68,165,71,229,69,176,194,169,3,141,15,210,108,226,2,52
	db	46,48,112

; Ending Header for loader #2
endseq2	db	250,4,250,4,224

exitcod	dw	4c00h
flags	db	0
len	dd	lodlen+endlen
ohand	dw	0
ahand	dw	0
anam	dw	atrnam
onam	dw	?
nfin	dw	?
spt	dw	?

obxnam	db	100h dup(?)
atrnam	db	100h dup(?)

head	dw	?,?
blok	db	blen dup(?)

	ENDS
	END	start