; ><-B00T V b. Fox

	IDEAL
	P386
	MODEL	TINY
	CODESEG
zero	db	100h dup(?)

blen	=	59*1024

m_pro	=	1	; /p switch
m_errs	=	2	; error/warning occured while current file
m_file	=	4	; single file (atr name for one file given)
m_lfn	=	8	; LFN search

eol	equ	13,10
eot	equ	13,10,'$'

struc	finddata16
	db	21 dup(?)
attr	db	?
time	dw	?
date	dw	?
fsize	dd	?
fname	db	13 dup(?)
	ends

struc	filetime32
	dd	?,?
	ends

struc	finddata32
attr	dd	?
creat	filetime32	?
acces	filetime32	?
write	filetime32	?
fsizeh	dd	?
fsizel	dd	?
	dd	?,?
fname	db	260 dup(?)
aname	db	14 dup(?)
	ends

MACRO	lda	_rg	; shorter than 'mov (e)ax, _rg'
_rge	SUBSTR	<_rg>, 1, 1
IFIDNI	_rge, <e>
	xchg	eax, _rg
ELSE
	xchg	ax, _rg
ENDIF
	ENDM

MACRO	sta	_rg	; shorter than 'mov _rg, (e)ax'
_rge	SUBSTR	<_rg>, 1, 1
IFIDNI	_rge, <e>
	xchg	_rg, eax
ELSE
	xchg	_rg, ax
ENDIF
	ENDM

MACRO	dos	_func	; call DOS function
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

MACRO	print	_text	; print ascii$ text
IFNB	<_text>
	mov	dx, offset _text
ENDIF
	dos	9
	ENDM


start:
	db	1536 dup(0)	; COMpack sux
	mov	[spt], sp
	print	hello

; Get arguments: obxnam, atrnam & /p switch
; Set onam & anam to end of filenames
	mov	si, 81h
	mov	bx, offset onam

arg1:	lodsb
	cmp	al, ' '
	je	arg1		; skip spaces
	cmp	al, '-'
	je	swit
	cmp	al, '/'
	jne	nswit
; Switch
swit:	lodsb
	and	al, 0dfh
	cmp	al, 'P'
	jne	usg
	or	[flags], m_pro	; '/P'
	jmp	arg1

nswit:	cmp	al, 0dh
	je	argx
; Filename
	cmp	bx, offset enam
	jae	usg		; two names already parsed
	mov	di, [bx]
	mov	ah, '"'
	cmp	al, ah
	je	qname		; "file name with spaces"
	mov	ah, ' '
gname:	stosb			; copy name
qname:	lodsb
	cmp	al, ah		; space/'"', eol and '/' terminate name
	je	xname
	cmp	al, 0dh
	je	bname
	cmp	al, '/'
	jne	gname
bname:	dec	si
xname:	mov	[bx], di	; save end of name ptr
	inc	bx
	inc	bx
	mov	[byte di], 0
	jmp	arg1

; Usage
usg:	print	usgtxt
	dos	4c03h

; End of arguments
argx:	cmp	bx, offset anam
	jb	usg		; no obxnam given

; Find where obx FILE name begins
	mov	di, [onam]
	lea	cx, [di+1+zero-obxnam]
fofna1:	dec	di
	cmp	[byte di], '\'
	je	fofnax
	cmp	[byte di], ':'
	loopne	fofna1
fofnax:	inc	di
	mov	[ofna], di

; Is atr given?
	cmp	bx, offset anam
	ja	atrgvn		; atr given

; Only obx given
; Move path of obx to atrnam
	mov	si, offset obxnam
	mov	di, offset atrnam
mobat1:	lodsb
	stosb
	cmp	al, '\'
	je	mobat2
	cmp	al, ':'
	jne	mobat3
mobat2:	mov	[anam], di
mobat3:	test	al, al
	jnz	mobat1
	mov	di, [anam]
	mov	[byte di], 0
	jmp	srvobx

; Atr given
; Delete trailing '\' if not "\" or "C:\"
atrgvn:	mov	di, [anam]
	dec	di
	cmp	[byte di], '\'
	jne	atrg1
	mov	[anam], di
	cmp	di, offset atrnam
	jbe	atrg1
	cmp	[byte di-1], ':'
	je	atrg1
	mov	[byte di], 0
atrg1:
; Check if it is file or dir
	mov	dx, offset atrnam
	xor	bx, bx		; try LFN function
	stc
	dos	7143h
	jnc	chkafd
	cmp	ax, 7100h	; LFN not supported
	jne	afile		; possibly file/dir doesn't exist -> file
	dos	43h		; call MS-DOS function 4300h
	jc	afile		; failed -> file
chkafd:	test	cl, 10h
	jnz	adir
; It is file
; Add .atr extension, if none
afile:	or	[flags], m_file
	mov	di, [anam]
	lea	cx, [di+zero-atrnam]
	mov	eax, 'rta.'
	call	adext
	jmp	srvobx
; It is dir
; Add trailing '\'
adir:	mov	di, [anam]
	mov	[byte di], '\'
	inc	[anam]

; Serve obx
; Add .obx extension, if none
srvobx:	mov	di, [onam]
	lea	cx, [di+zero-obxnam]
	mov	eax, 'xbo.'
	call	adext

; Find first file
	mov	dx, offset obxnam
	mov	cx, 7		; try LFN
	mov	si, 1
	mov	di, offset f32
	stc
	dos	714eh
	jnc	flfn
	cmp	ax, 7100h	; LFN not supported
	jne	nofil
	xor	cx, cx		; call MS-DOS function 4Eh
	dos	4eh
	jnc	main1
nofil:	print	e_nofil		; "No file found"
	dos	4c02h

flfn:	or	[flags], m_lfn	; LFN successfull
	mov	[fhand], ax

; Main loop - convert found file
main1:	and	[flags], not m_errs
	mov	[ohand], 0
	mov	[ahand], 0
	mov	[len], lodlen+endlen

; Move name from finddata to obxnam
	mov	si, offset (finddata16 80h).fname
	test	[flags], m_lfn
	jz	nolfn1
	mov	si, offset f32.fname
nolfn1:	mov	di, [ofna]
mona1:	lodsb
	stosb
	test	al, al
	jnz	mona1

; Print "file.obx"
	mov	si, offset obxnam
	call	printz

; Open obx for reading
	mov	bp, offset e_open
	mov	dx, offset obxnam	; MS-DOS
	mov	ax, 3d00h
	test	[flags], m_lfn
	jz	nolfn2
	mov	si, dx			; LFN
	xor	bx, bx
	mov	dx, 1
	mov	ax, 716ch
nolfn2:	file
	mov	[ohand], ax

; Check if Atari executable
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

; Set default run address at first block
	mov	ax, [head]
	mov	[l1runl], al
	mov	[l2runl], al
	mov	[l1runh], ah
	mov	[l2runh], ah

; Print "->"
	print	arrow

; Atr FILE name given?
	test	[flags], m_file
	jnz	sfile
; No: move name from obx, replacing extension with ".atr"
	mov	si, [ofna]	
	mov	di, [anam]
mona2:	lodsb
	stosb
	cmp	al, '.'
	jne	mona2
	mov	eax, 'rta'
	stosd
sfile:

; Print "file.atr"
	mov	si, offset atrnam
	call	printz			; file.atr

; Create atr file
	mov	bp, offset e_creat
	mov	dx, offset atrnam
	xor	cx, cx
	mov	ax, 3c00h
	test	[flags], m_lfn
	jz	nolfn3
	mov	si, dx
	mov	bx, 1
	mov	dx, 12h			; create or truncate
	mov	ax, 716ch
nolfn3:	file
	mov	[ahand], ax

; Print "..."
	print	kropki

; Write atr header
	mov	cx, beglen
	mov	dx, offset begin
	call	xwrite
; Write loader in boot sector
	mov	cx, lodlen
	mov	dx, offset stdlod
	test	[flags], m_pro
	jz	stlo
	mov	dx, offset prolod
stlo:	call	xwrite
	jmp	firs

; Converting
; Read obx header
skff:	call	xreadh
	jb	chtrun
	cmp	[head], -1
	je	skff
	mov	dx, offset head+2
	call	xread2
	jb	trunca

; Read block
firs:	mov	cx, [head+2]
	sub	cx, [head]
	inc	cx
	cmp	cx, blen
	jbe	okhead
	mov	cx, blen
okhead:	mov	dx, offset blok
	call	xread
	jb	trunc
; Write
	call	xwrihd
	jmp	skff

; Check if block is truncated
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
; Warning
warfin:	call	warni

; End of file
; Write endsequence
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
fuls:

; Write number of paragraphs (para=16 bytes) to atr
	xor	cx, cx		; seek back to para's atr header field
	mov	dx, 2
	mov	bp, offset e_write
	file	4200h
	shr	[len], 4
	mov	cx, 2
	mov	dx, offset len
	call	xwrite

; Close files
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

; Find next file
	test	[flags], m_lfn
	jnz	lfnnx

	dos	4fh		; MS-DOS function
	jc	fin
nexfil:	test	[flags], m_file
	jnz	singl
	jmp	main1

lfnnx:	mov	bx, [fhand]	; LFN function
	mov	si, 1
	mov	di, offset f32
	dos	714fh
	jnc	nexfil

	dos	71a1h		; LFN search close

fin:	mov	ax, [exitcod]
	dos

singl:	print	e_singl
	dos	4c02h

; Add extension if none (di=end of name, cx=len, eax=ext)
adext:	mov	bx, di
adext1:	dec	bx
	cmp	[byte bx], '.'
	je	adextr
	cmp	[byte bx], '\'
	loopne	adext1
	stosd
adextr:	mov	[byte di], 0
	ret

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

hello	db	'X-BOOT 5.0 by Fox/Taquart',eot
usgtxt	db	'Converts Atari 8-bit executables to .ATR disk images.',eol
	db	'Syntax: XBOOT [/p] obxfiles [atrpath][atrfile]',eol
	db	'/p  Write professional loader rather than standard.'
eoltxt	db	eot
arrow	db	' -> $'
kropki	db	' ... $'
oktxt	db	'OK$'
w_mem	db	eol,'  WARNING: Memory conflict$'
w_prof	db	eol,'  WARNING: Professional loader needed$'
w_trunc	db	eol,'  WARNING: File is truncated$'
e_nofil	db	'ERROR: File not found',eot
e_singl	db	'ERROR: Single target for many files',eot
e_nota	db	eol,'  ERROR: Not Atari executable$'
e_open	db	eol,'  ERROR: Can''t open file$'
e_read	db	eol,'  ERROR: Disk read error$'
e_creat	db	eol,'  ERROR: Can''t create file$'
e_write	db	eol,'  ERROR: Disk write error$'

; ATR Header
begin	dw	296h,0,80h,4 dup(0)
	db	0,1
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
	db	53,46,48
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
	db	70,197,68,165,71,229,69,176,194,169,3,141,15,210,108,226,2,53
	db	46,48,112

; Ending Header for loader #2
endseq2	db	250,4,250,4,224

exitcod	dw	4c00h
flags	db	0
len	dd	lodlen+endlen
onam	dw	obxnam
anam	dw	atrnam
enam:
fhand	dw	?
ohand	dw	?
ahand	dw	?
ofna	dw	?
spt	dw	?

obxnam	db	100h dup(?)
atrnam	db	100h dup(?)

f32	finddata32	?

head	dw	?,?
blok	db	blen dup(?)

	ENDS
	END	start