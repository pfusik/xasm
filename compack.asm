; COMpack
; b. Fox

	IDEAL
	P386
	MODEL	TINY
	CODESEG
	ORG	100h
	include	'fox.mak'
start:
;	db	1024 dup(0)	;4 self-packing

inplen	=	24000
outlen	=	27000

	print	hello
	mov	di, 81h
	movzx	cx, [di-1]
	jcxz	usg
	mov	al, ' '
	repe	scasb
	je	usg
	push	cx di
	dec	di
	inc	cx
	mov	al, '?'
	repne	scasb
	pop	di cx
	jne	nousg

usg:	print	usgtxt
	int	20h

getfil:	lea	si, [di-1]
	mov	al, ' '
	repne	scasb
	jne	noout1
	dec	di
noout1:	mov	cx, di
	sub	cx, si
	mov	di, offset fname
	rep	movsb
	mov	bx, di
srchex:	dec	bx
	cmp	[byte bx], '\'
	je	addext
	cmp	[byte bx], '.'
	je	extexs
	cmp	bx, offset fname
	ja	srchex
addext:	mov	ax, 'c.'
	stosw
	mov	ax, 'mo'
	stosw
extexs:	mov	[word di], 0a0dh
	mov	[byte di+2], '$'
	print	namtxt
	print	fname
	mov	[byte di], 0
rts:	ret

	smartdisk

nousg:	print	srctxt
	call	getfil
	push	si

	fopen
	mov	cx, inplen
	fread	inpbuf
	mov	dx, offset lontxt
	cmp	ax, inplen
	je	panic
	push	ax
	add	[filend], ax
	fclose
	pop	cx

	mov	dx, offset emptxt
	jcxz	panic
	mov	di, offset inpbuf
	xor	al, al
	repe	scasb
	jne	spox
panic:	print
	int	20h

spox:	dec	di
	push	di
	mov	[filbgn], di
	sub	di, offset inpbuf
	add	[destad], di
	add	[reljad], di
	lda	cx
	inc	ax
	call	prilen

	pop	bx
	mov	si, offset firflg
	mov	di, offset outbuf

pack1:	push	si di
	mov	ax, 1
	mov	bp, [filend]
	lea	si, [bx-0ffh]
	cmp	si, [filbgn]
	jnb	pack2
	mov	si, [filbgn]
	cmp	si, bx
	je	packn

pack2:	mov	di, bx
	mov	cx, bp
	sub	cx, bx
	push	si
	repe	cmpsb
	pop	si
	je	pack3
	dec	di
pack3:	mov	cx, di
	sub	cx, bx
	cmp	cx, ax
	jbe	pack4
	lda	cx
	mov	dx, si
pack4:	inc	si
	cmp	si, bx
	jb	pack2

packn:	pop	di si
	mov	bp, ax
	sta	cx
	mov	ax, 1

putfl1:	cmp	cx, 2
	rcl	[byte si], 1
	jnc	putfl2
	mov	si, di
	stosb
putfl2:	loop	putfl1

	cmp	bp, ax
	mov	al, [bx]
	je	putbyt
	mov	al, dl
	sub	al, bl
putbyt:	stosb
	mov	ah, 1
	cmp	[si], ah
	jne	swpflg
	mov	[si], ax
	inc	si
swpflg:	add	bx, bp
	cmp	bx, [filend]
	jb	pack1

	shl	[byte si], 1
	jnc	corfl1
	mov	al, 80h
	stosb
	jmp	corfl3
corfl1:	stc
corfl2:	rcl	[byte si], 1
	jnc	corfl2
corfl3:	rcl	[firflg], 1	;+
	xor	al, al	
	stosb

	sub	di, offset depack
	mov	[filend], di

	print	pkdtxt
	pop	di
	mov	cx, 81h
	add	cl, [80h]
	sub	cx, di
	jz	nowri
	mov	al, ' '
	repe	scasb
	je	nowri
	mov	ax, [filend]
	inc	ah
	cmp	ax, [destad]
	ja	nospac

	call	getfil
	fcreate
	mov	cx, [filend]
	fwrite	depack
	fclose

nowri:	mov	ax, [filend]

prilen:	mov	di, offset lenlst
	mov	bx, 10
outnm1:	xor	dx, dx
	div	bx
	add	dl, '0'
outnm2:	mov	[di], dl
	dec	di
	test	ax, ax
	jnz	outnm1
	mov	dl, ' '
	cmp	di, offset lennum
	jnb	outnm2
	print	lentxt
	ret

nospac:	mov	dx, offset zertxt
	dos	9
	jmp	nowri

hello	db	'COMpack 1.0 by Fox/Taquart',eot
usgtxt	db	'This is FREEWARE packer for .COM programs.',eol
	db	'Syntax:',eol
	db	'COMPACK inpfile [outfile]',eol
	db	'"inpfile" specifies source path\filename',eol
	db	'"outfile" specifies target path\filename',eol
	db	'The ".COM" extension of filename is default and you don''t have to write it',eol
	db	'If you don''t give "outfile" parameter, no file will be saved',eol
	db	'and you can only watch the results of packing',eol
zertxt	db	'If you want the file saved, you must compile some zero bytes at the beginning',eol
	db	'of file to reserve the space for packed data. The code should immediately',eol
	db	'follow the zeros.',eot

srctxt	db	'Source file:',eot
pkdtxt	db	'Packed file:',eot
namtxt	db	'  Name: $'
lentxt	db	'Length: '
lennum	db	'    '
lenlst	db	'  bytes',eot
emptxt	db	'File is empty!',eot
lontxt	db	'File is too long!',eot
	smarterr

filbgn	dw	inpbuf
filend	dw	inpbuf

depack:	mov	si, offset packed-depack+100h
	mov	di, 100h
destad	=	word $-2
	mov	al, 1
firflg	=	byte $-1
	xor	cx, cx
dep1:	movsb
	dec	cx
dep2:	inc	cx
dep3:	add	al, al
	jnz	dep4
	lodsb
	adc	al, al	;+
dep4:	jnc	dep2
	jcxz	dep1
	sbb	bx, bx	;+
	and	bl, [si]
	db	0fh,84h		;jz near
reljad	dw	depack-reljmp
reljmp:	inc	si
	inc	cx
	push	si
	lea	si, [di+bx]
	rep	movsb
	pop	si
	jmp	dep3
packed:

outbuf	db	outlen dup(?)

fname:

inpbuf	db	inplen dup(?)

	ENDS
	END	start