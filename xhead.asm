	IDEAL
	P386
	MODEL	TINY
	CODESEG
	ORG	100h
	include	'fox.mak'

smartio	=	1

start:	print	hello
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

usg:	mov	dx, offset usgtxt
panic:	print
	int	20h

	smartdisk

read:	mov	cx, 2
	fread	addr
	cmp	ax, 2
	mov	ax, [addr]
	ret

nousg:	lea	dx, [di-1]
	mov	al, ' '
	repne	scasb
	jne	okend
	dec	di
okend:	mov	[byte di], 0
	fopen

	call	read
	mov	dx, offset notbin
	inc	ax
	jnz	panic

head1:	inc	[mods]
	call	read
	jb	eof
	cmp	ax, 0ffffh
	je	head1

	inc	[blox]
	dec	[mods]
	mov	[begn], ax
	mov	dl, ' '
	dos	2
	mov	ax, [begn]
	call	prword
	mov	dl, '-'
	dos	2

	call	read
	mov	dx, ax
	sub	dx, [begn]
	inc	dx
	call	prword
	cmp	dx, 2
	jne	skip
	cmp	[begn], 2e0h
	je	pexec
	cmp	[begn], 2e2h
	jne	skip
	inc	[inits]
pexec:	mov	dl, ' '
	dos	2
	call	read
	call	prword
	jmp	heade

skip:	xor	cx, cx
	file	4201h
heade:	PEOL
	jmp	head1

eof:	xor	cx, cx
	xor	dx, dx
	file	4202h
	push	ax
	mov	al, dl
	call	pbyte
	pop	ax
	call	prword
	print	byttxt
	mov	ax, [blox]
	call	prword
	print	blotxt
	mov	ax, [inits]
	call	prword
	print	initxt
	mov	ax, [mods]
	call	prword
	print	modtxt
	fclose
	ret

prword:	push	ax
	mov	al, ah
	call	pbyte
	pop	ax
pbyte:	ror	ax, 4
	and	al, 0fh
	call	pdig
	shr	ax, 12
pdig:	d2a
	pusha
	sta	dx
	dos	2
	popa
	ret

hello	db	'X-HEAD 1.0 by Fox/Taquart',eot
usgtxt	db	'You must specify a file to analyze.',eot
notbin	db	'File is not Atari executable!',eot
	smarterr
byttxt	db	' bytes',eot
blotxt	db	' blocks',eot
initxt	db	' inits',eot
modtxt	db	' modules',eot

blox	dw	0
inits	dw	0
mods	dw	0

addr	dw	?
begn	dw	?

	ENDS
	END	start