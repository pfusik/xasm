	IDEAL
	P386
	MODEL	TINY
	CODESEG
zero	db	100h dup(?)

ratio	equ	671/1000
timeAnswer	=	2500*ratio
timeChecksum	=	1500*ratio
timeSending	=	600*ratio
timeNormal	=	900*ratio
timeBefore	=	1500*ratio
timeBetween	=	600*ratio
timeUltra	=	310*ratio

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

MACRO	fread	_fbufr
	mov	dx, offset _fbufr
	call	xread
	ENDM

MACRO	print	_text
IFNB	<_text>
	mov	dx, offset _text
ENDIF
	dos	9
	ENDM


start:
	db	1536 dup(0)	;compack
	print	hello

	mov	si, 81h
	mov	di, offset obxnam

arg1:	lodsb
	cmp	al, ' '
	je	arg1
	cmp	al, '/'
	jne	nswit
	lodsb
	cmp	al, '4'
	ja	ndigt
	sub	al, '1'
	jb	usg
	mov	[byte port], al
	jmp	arg1
ndigt:	and	al, 0dfh
	cmp	al, 'P'
	jne	usg
	mov	[prof], al
	jmp	arg1
nswit:	cmp	al, 0dh
	je	argx
	cmp	di, offset obxnam
	ja	usg
mnam1:	stosb
	lodsb
	cmp	al, ' '
	je	mnam2
	cmp	al, '/'
	je	mnam2
	cmp	al, 0dh
	jne	mnam1
mnam2:	dec	si
	mov	bx, di
	lea	cx, [di+zero-obxnam]
adex1:	dec	bx
	cmp	[byte bx], '.'
	je	adexn
	cmp	[byte bx], '\'
	loopne	adex1
	mov	eax, 'XBO.'
	stosd
adexn:	mov	[byte di], 0
	jmp	arg1

usg:	print	usgtxt
	dos	4c03h

noport:	mov	dx, offset nocom
	jmp	panic
nobin:	mov	dx, offset e_nota
	jmp	panic

xdisk:	push	bp
	dos
	pop	dx
	jc	panic
	ret

panic:	print
	dos	4c02h

xread:	mov	bp, offset e_read
	file	3fh
	cmp	ax, cx
	ret

argx:	cmp	di, offset obxnam
	jbe	usg
	mov	bx, [port]
	add	[comnum1], bl
	add	[comnum2], bl
	add	bx, bx
	push	ds
	push	40h
	pop	ds
	mov	cx, [bx]
	pop	ds
	jcxz	noport
	mov	[port], cx

	mov	dx, offset obxnam
	mov	bp, offset e_open
	file	3d00h			; open for reading
	sta	bx
	mov	cx, 2
	fread	dcb
	cmp	[word dcb], 0ffffh
	jne	nobin

	mov	dx, [port]
	mov	al, 3
	add	dl, al
	out	dx, al
	and	dl, 0feh
	xor	al, al
	out	dx, al

	print	rboot

	mov	dx, [port]
	mov	cx, 6
	call	speed
	and	dl, 0f8h
	mov	al, 5
	out	dx, al
	in	al, dx

	mov	di, offset dcb

main:	mov	dx, [port]
	in	al, 60h
	cmp	al, 1
	je	byebye

	add	dl, 5
	in	al, dx
	test	al, 1
	jz	main

	and	dl, 0f8h
	in	al, dx
	mov	[di+5], al
	stosb
	cmp	di, offset dcb+5
	jb	sk1
	mov	di, offset dcb
sk1:	cmp	[byte di], 31h
	jne	main

	cmp	[byte di+1], 'R'
	je	xcom_r
	cmp	[byte di+1], 'S'
	jne	main

xcom_s:	call	ack
	mov	si, offset statdat
	mov	cx, 5
	call	send
	print	booting
	jmp	main

xcom_r:	cmp	[word di+2], 1
	jne	main
	call	ack
	mov	si, offset bootstd
	test	[prof], 0ffh
	jz	sk3
	mov	si, offset bootpro
sk3:	mov	cx, 129
	call	send
	call	wate

	mov	cx, 2
	call	speed
	mov	[trtime], timeUltra

	test	[prof], 0ffh
	jz	nodrom
	call	wtblok
	mov	si, offset bankdat
	mov	cx, 4
	call	send
nodrom:

	call	wtblok

ffff:	mov	cx, 2
	fread	head
	jb	kpliq
	cmp	[head], 0ffffh
	je	ffff
	mov	cx, 2
	fread	head+2
	jb	kpliq
	mov	di, offset hexnum
	mov	ax, [head]
	call	hexw
	inc	di
	mov	ax, [head+2]
	call	hexw
	print	loading
	mov	ax, [head]
	dec	ax
	sub	[head+2], ax

dalej:	mov	ax, [head+2]
	cmp	ax, 100h
	jbe	sk2
	mov	ax, 100h
sk2:	sub	[head+2], ax
	sta	cx
	fread	buf+3
	mov	cx, ax
	jcxz	kpliq
	mov	si, offset buf
	add	ax, [head]
	dec	ah
	xchg	al, ah
	mov	[si], ax
	mov	al, cl
	neg	al
	mov	[si+2], al
	add	cx, 3
	call	send

	inc	[byte high head]
	call	wtblok
	cmp	[head+2], 0
	jnz	dalej
	jmp	ffff

kpliq:
	mov	si, offset runstd
	test	[prof], 0ffh
	jz	sk4
	mov	si, offset runpro
sk4:	mov	cx, 4
	call	send

	mov	bp, offset e_read
	file	3eh		; close file
	print	done
byebye:	dos	4c00h

wtblok:	in	al, 60h
	cmp	al, 1
	je	byebye
	and	dl, 0f8h
	add	dl, 5
	in	al, dx
	test	al, 1
	jz	wtblok
	and	dl, 0f8h
	in	al, dx
	mov	si, offset bttime
	jmp	wate

speed:	and	dl, 0f8h
	add	dl, 3
	in	al, dx
	push	ax
	or	al, 80h
	out	dx, al
	and	dl, 0f8h
	mov	ax, cx
	out	dx, ax
	add	dl, 3
	pop	ax
	out	dx, al
	ret

send:	push	si
	mov	si, offset trtime
	call	wate
	pop	si
	mov	dx, [port]
	outsb
	loop	send
	ret

ack:	mov	si, offset ackdat
	call	wate
	outsb
	call	wate
	outsb
wate:	in	al, 61h
	and	al, 0fch
	out	61h, al
	mov	ah, al
	mov	al, 0b0h
	out	43h, al
	lodsb
	out	42h, al
	lodsb
	out	42h, al
	mov	al, 1
	or	al, ah
	out	61h, al
	mov	al, 080h
	out	43h, al
wate1:	in	al, 42h
	in	al, 42h
	cmp	al, 255
	je	wate1
wate2:	in	al, 42h
	in	al, 42h
	cmp	al, 255
	jne	wate2
	mov	al, ah
	out	61h, al
	ret

hexw:	push	ax
	mov	al, ah
	call	hexb
	pop	ax
hexb:	aam	10h
	cmp	al, 10
	sbb	al, 69h
	das
	xchg	al, ah
	cmp	al, 10
	sbb	al, 69h
	das
	stosw
	ret

ackdat:	dw	timeAnswer
	db	'A'
	dw	timeChecksum
	db	'A'
	dw	timeSending

statdat	db	098h,0FFh,001h,000h,099h
bankdat	db	0D2h,002h,0FFh,0FEh

runstd	db	006h,060h,0FFh,0E0h
runpro	db	003h,05Fh,0FFh,0E0h

bootstd:
 db 000h,001h,000h,007h,007h,007h,0A9h,060h,078h,0EEh,00Eh,0D4h,0A9h,008h,08Dh,004h
 db 0D2h,0A9h,000h,08Dh,006h,0D2h,0A9h,028h,08Dh,008h,0D2h,08Dh,009h,0D2h,0A9h,023h
 db 08Dh,00Fh,0D2h,08Dh,00Dh,0D2h,08Dh,00Ah,0D4h,00Ah,090h,0FAh,0A9h,013h,08Dh,00Fh
 db 0D2h,0A0h,002h,020h,061h,007h,099h,04Ah,007h,0B9h,003h,007h,099h,0E1h,002h,048h
 db 088h,0D0h,0F0h,020h,061h,007h,0AAh,020h,061h,007h,09Dh,000h,000h,0E8h,0D0h,0F7h
 db 0A5h,010h,08Dh,00Eh,0D2h,0A9h,003h,08Dh,00Fh,0D2h,04Eh,00Eh,0D4h,058h,06Ch,0E2h
 db 002h,0A9h,020h,08Dh,00Eh,0D2h,02Ch,00Eh,0D2h,0D0h,0FBh,08Ch,00Eh,0D2h,0ADh,00Dh
 db 0D2h,060h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h
 db 089h
	dw	timeBefore

bootpro:
 db 000h,001h,000h,004h,007h,004h,0A9h,060h,078h,0EEh,00Eh,0D4h,0EEh,000h,0D4h,0A9h
 db 008h,08Dh,004h,0D2h,0A9h,000h,08Dh,006h,0D2h,0A9h,028h,08Dh,008h,0D2h,08Dh,009h
 db 0D2h,0A9h,023h,08Dh,00Fh,0D2h,08Dh,00Dh,0D2h,08Dh,00Ah,0D4h,00Ah,090h,0FAh,0A9h
 db 013h,08Dh,00Fh,0D2h,0A0h,002h,020h,060h,004h,099h,04Dh,004h,0B9h,003h,004h,099h
 db 0E1h,002h,048h,088h,0D0h,0F0h,020h,060h,004h,0AAh,020h,060h,004h,09Dh,000h,000h
 db 0E8h,0D0h,0F7h,0A5h,010h,08Dh,00Eh,0D2h,0A9h,003h,08Dh,00Fh,0D2h,06Ch,0E2h,002h
 db 0A9h,020h,08Dh,00Eh,0D2h,02Ch,00Eh,0D2h,0D0h,0FBh,08Ch,00Eh,0D2h,0ADh,00Dh,0D2h
 db 060h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h
 db 0AEh
	dw	timeBefore

hello	db	'X-LOAD 1.0 by Fox/Taquart',eot
usgtxt	db	'Syntax: XLOAD obxfile [options]',eol
	db	'/1 - /4  Specify COM port (default COM2)',eol
	db	'/p       Professional loader',eot
nocom	db	'COM'
comnum1	db	'1 not found!',eot
rboot	db	'Ready for booting Atari at COM'
comnum2	db	'1...',eot
booting	db	'Booting...',eot
loading	db	'Loading '
hexnum	db	'    -    ',eot
done	db	'Done.',eot
e_nota	db	'ERROR: Not Atari executable',eot
e_open	db	'ERROR: Can''t open file',eot
e_read	db	'ERROR: Disk read error',eot

prof	db	0
port	dw	1
trtime	dw	timeNormal
bttime	dw	timeBetween
dcb	db	5 dup(0),5 dup(?)
head	dw	?,?
buf	db	103h dup(?)
obxnam:

	ENDS
	END	start