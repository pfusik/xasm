; ><-B00T III b. Fox

	IDEAL
	P386
	MODEL	TINY
	CODESEG
	ORG	100h
	include	'fox.mak'

blen	=	60*1024

start:
	db	1024 dup(0)	;for COMpack
	print	hello
	mov	di, 81h
	movzx	cx, [di-1]
	jcxz	usg
	mov	al, '?'
	repne	scasb
	jne	nousg

usg:	mov	dx, offset usgtxt
panic:	print
	dos	4c01h

getfil:	mov	ch, -1
	mov	al, ' '
	repe	scasb
	mov	dx, offset fname
	lea	si, [di-1]
	cmp	[byte si], 0dh
	je	usg
	mov	di, dx
movfn1:	movsb
	cmp	[si], al
	ja	movfn1
	mov	bx, di
srchex:	dec	bx
	cmp	[byte bx], '\'
	je	addext
	cmp	[byte bx], '.'
	je	extexs
	cmp	bx, dx
	ja	srchex
addext:	xchg	eax, ebp
	stosd
extexs:	mov	[byte di], 0
rts:	ret

	smartdisk

badf:	mov	dx, offset badtxt
	jmp	panic

nousg:	mov	ch, -1
	mov	di, 81h
	mov	al, ' '
	repe	scasb
	mov	ax, [di-1]
	inc	di
	or	ah, 20h
	cmp	ax, 'p/'
	je	romsw
	dec	[romfl]
	mov	di, 81h
romsw:	mov	ebp, 'moc.'
	call	getfil
	push	si

	fopen
	mov	cx, blen
	fread	bufr
	mov	dx, offset lontxt
	cmp	ax, blen
	jnb	panic
	mov	[len], ax
	fclose

	mov	si, offset bufr
	mov	di, si
	lodsw
	cmp	ax, -1
	jne	badf

	mov	ax, [si]
	mov	[l1runl], al
	mov	[l2runl], al
	mov	[l1runh], ah
	mov	[l2runh], ah

cutf1:	lodsw
	cmp	ax, -1
	je	cutf1
	stosw
	sta	bx
	lodsw
	stosw
	sub	ax, bx
	jb	badf
	inc	ax
	sta	cx
	rep	movsb
cutfn:	mov	ax, si
	sub	ax, offset bufr
	cmp	ax, [len]
	jb	cutf1
	mov	si, offset endseq1
	cmp	[romfl], 0
	jz	stdld
	push	di
	mov	si, offset romlod
	mov	di, offset sect
	mov	cx, 64
	rep	movsw
	pop	di
	mov	si, offset endseq2
stdld:	mov	cx, endlen
	rep	movsb
	mov	cx, offset sect
	sub	cx, di
	and	cx, 7fh
	xor	al, al
	rep	stosb
	sub	di, offset begin
	mov	[len], di
	shr	di, 4
	dec	di
	mov	[paras], di

	pop	di
	mov	ebp, 'rta.'
	call	getfil
	fcreate
	mov	cx, [len]
	mov	dx, offset begin
	fwrite
	fclose
	print	oktxt
	dos	4c00h

; Poetry
hello	db	'X-BOOT 3.1 by Fox/Taquart',eot
usgtxt	db	'Converts Atari 8-bit executable into .ATR disk image.',eol
	db	'Usage: XBOOT [/p] comfile atrfile',eol
	db	'Use /p switch to write professional loader rather than standard.',eot
oktxt	db	'O.K.',eot
badtxt	db	'Bad format of file!',eot
lontxt	db	'File too long',eot
	smarterr

romfl	db	1

; Ending Header for loader #1
endseq1	db	233,7,235,7,108,224,2
; Ending Header for loader #2
endseq2	db	244,4,246,4,108,224,2
endlen	=	$-endseq2

; Loader #2 (rom)
romlod:	db	96,1,128,4,119,228,169,0,141,47,2
	db	169,82,141,200,2,165,20,197,20,240,252,169
l2runl	db	128,141,224,2,169
l2runh	db	4,141,225,2,160,254,169,128,141,226,2,169,4,141,227,2,162,251,149
	db	72,232,134,67,76,188,4,230,68,208,2,230,69,200,16,32,238,10
	db	3,208,3,238,11,3,169,255,141,1,211,78,14,212,88,32,83,228
	db	56,48,170,160,0,120,140,14,212,206,1,211,185,0,4,166,67,208
	db	200,129,68,165,68,197,70,208,200,165,69,197,71,208,194,152,72,32
	db	253,4,104,168,16,165,108,226,2

; ATR Header
begin	dw	296h
paras	dw	0
	dw	80h,5 dup(0)
; Atari Boot Sector(s)
sect:
; Loader #1 (std)
	db	96,1,128,7,119,228,160,215,185,30,7
	db	145,88,200,192,226,144,246,169
l1runl	db	128,141,224,2,169
l1runh	db	7,141,225,2,169
	db	7,141,5,3,160,255,140,1,211,136,169,128,141,226,2,169,7,141
	db	227,2,162,251,149,72,232,134,67,76,193,7,230,68,208,2,230,69
	db	200,16,16,238,10,3,208,3,238,11,3,32,83,228,56,48,174,160
	db	0,185,0,7,166,67,208,216,129,68,165,68,197,70,208,216,165,69
	db	197,71,208,210,152,72,32,242,7,104,168,16,181,108,226,2,44,111
	db	97,100,105,110,103,14,14,14,0
beglen	=	$-begin
bufr	db	blen dup(?)

len	dw	?

fname	db	128 dup(?)

	ENDS
	END	start