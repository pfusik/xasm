	IDEAL
	P386
	MODEL	TINY
	CODESEG
	ORG	100h
	include	'fox.mak'

start:	mov	[csum], 0
	fopen	inpfile
	mov	[ihand], bx
	fcreate	outfile
	mov	[ohand], bx

	mov	cx, 8
main:	push	cx
	mov	bx, [ihand]
	mov	cx, 16
	fread	buf

	mov	si, offset buf
	mov	di, offset data
	mov	cx, 16
	jmp	c0
c1:	mov	al, ','
	stosb
c0:	mov	al, '0'
	stosb
	mov	al, [si]
	add	[csum], al
	adc	[csum], 0
	shr	al, 4
	d2a
	stosb
	lodsb
	and	al, 0fh
	d2a
	stosb
	mov	al, 'h'
	stosb
	loop	c1
	mov	ax, 0a0dh
	stosw

	mov	bx, [ohand]
	mov	cx, 85
	fwrite	line

	pop	cx
	loop	main

	mov	bx, [ihand]
	fclose
	mov	bx, [ohand]
	mov	di, offset data+1
	mov	al, [csum]
	shr	al, 4
	d2a
	stosb
	mov	al, [csum]
	and	al, 0fh
	d2a
	stosb
	mov	al, 'h'
	stosb
	mov	ax, 0a0dh
	stosw
	mov	cx, 10
	fwrite	line
	fclose

	mov	eax, '.orp'
	cmp	eax, [dword typ1]
	je	wroc
	mov	[dword typ1], eax
	mov	[dword typ2], eax
	jmp	start
wroc:	ret

inpfile	db	'\atari\xasm\xload'
typ1	db	'std.obx',0
outfile	db	'xload'
typ2	db	'std.db',0

line	db	' db '
data	db	81 dup(?)
ihand	dw	?
ohand	dw	?
buf	db	16 dup(?)
csum	db	?

	ENDS
	END	start