;b. Fox/Tqa

eol	equ	13,10
eot	equ	13,10,'$'

;±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±

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

;±±±±±±± DOS / FILE I/O ±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±

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
IFDEF	smartio
	call	xdisk
ELSE
	int	21h
ENDIF
	ENDM

MACRO	smartdisk
smartio	=	1
xdisk:	dos
IFDEF	rts
	jnc	rts
ELSE
	jc	_derr
	ret
_derr:
ENDIF
	mov	dx, offset errtxt
	jmp	panic
ENDM

MACRO	smarterr
errtxt	db	'Disk error!',eot
	ENDM

MACRO	fcreate	_fname	; ENTRY: DS:_fname|dx = ASCIIZ fname, RETURN: bx = handle
IFNB	<_fname>
	mov	dx, offset _fname
ENDIF
	xor	cx, cx
	file	3ch
	sta	bx
	ENDM

MACRO	fopen	_fname	; ENTRY: DS:_fname|dx = ASCIIZ fname, RETURN: bx = handle
IFNB	<_fname>
	mov	dx, offset _fname
ENDIF
	file	3d00h
	sta	bx
	ENDM

MACRO	fupdate	_fname	; ENTRY: DS:_fname|dx = ASCIIZ fname, RETURN: bx = handle
IFNB	<_fname>
	mov	dx, offset _fname
ENDIF
	file	3d02h
	sta	bx
	ENDM

MACRO	fclose		; ENTRY: bx = handle
	file	3eh
	ENDM

MACRO	fread	_fbufr	; ENTRY: DS:_fbufr = buffer, cx = no. of bytes
IFNB	<_fbufr>
	mov	dx, offset _fbufr
ENDIF
	file	3fh
	ENDM

MACRO	fwrite	_fbufr	; ENTRY: DS:_fbufr = buffer, cx = no. of bytes
IFNB	<_fbufr>
	mov	dx, offset _fbufr
ENDIF
	file	40h
	ENDM

;±±±±±±± PRINT ±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±

MACRO	print	_text
IFNB	<_text>
	mov	dx, offset _text
ENDIF
	dos	9
	ENDM

MACRO	PEOL
	mov	dl, 13
	dos	2
	mov	dl, 10
	dos	2
	ENDM

MACRO	PrintAXdec
LOCAL	_outn1,_outn2,_dectxt,_cont
	mov	di, offset _dectxt+4
	mov	bx, 10
_outn1:	xor	dx, dx
	div	bx
	add	dl, '0'
_outn2:	mov	[di], dl
	dec	di
	test	ax, ax
	jnz	_outn1
	mov	dl, ' '
	cmp	di, offset _dectxt
	jnb	_outn2
	print	_dectxt
	jmp	_cont
_dectxt	db	5 dup(' '),eot
_cont:
	ENDM

MACRO	PrintEAXdec
LOCAL	_outn1,_outn2,_dectxt,_cont
	mov	di, offset _dectxt+9
	mov	ebx, 10
_outn1:	xor	edx, edx
	div	ebx
	add	dl, '0'
_outn2:	mov	[di], dl
	dec	di
	test	eax, eax
	jnz	_outn1
	mov	dl, ' '
	cmp	di, offset _dectxt
	jnb	_outn2
	print	_dectxt
	jmp	_cont
_dectxt	db	10 dup(' '),eot
_cont:
	ENDM

MACRO	D2A
	cmp	al, 10
	sbb	al, 69h
	das
	ENDM

MACRO	Printdig
	d2a
	sta	dx
	dos	2
	ENDM	

MACRO	PrintAL
 	push	ax
	shr	al, 4
	PrintDig
	pop	ax
	and	al, 0fh
	PrintDig
	ENDM

MACRO	PrintAX
	push	ax
	mov	al, ah
	PrintAL
	pop	ax
	PrintAL
	ENDM

MACRO	PrintEAX
	push	ax
	shr	eax, 16
	PrintAX
	pop	ax
	PrintAX
	ENDM

;±±±±±±± GFX ±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±

MACRO	setgfx	_gmode
	mov	ax, _gmode
	int	10h
	ENDM

MACRO	bar	_jaki
IFDEF	bars
	mov	dx, 3c8h
	mov	al, 0
	out	dx, al
	inc	dx
	mov	al, _jaki
	out	dx, al
	out	dx, al
	out	dx, al
ENDIF
	ENDM

MACRO	EndVBl
LOCAL	w1,w2
	mov	dx, 3dah
 w1:	in	al, dx
	test	al, 8
	jz	w1
 w2:	in	al, dx
	test	al, 8
	jnz	w2
	ENDM

MACRO	StartVBL
LOCAL	w1,w2
	mov	dx, 3dah
 w1:	in	al, dx
	test	al, 8
	jnz	w1
 w2:	in	al, dx
	test	al, 8
	jz	w2
	ENDM