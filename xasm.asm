; X-Assembler

	IDEAL
	P386
	MODEL	TINY
	CODESEG
	ORG	100h
start:
	db	5*1024 dup(0)	;for packing

l_icl	=	1000
l_org	=	1000*2
l_lab	=	48000

STRUC	com
cod	db	?
nam	db	?,?,?
vec	dw	?
	ENDS

STRUC	icl
prev	dw	?
handle	dw	?
line	dd	?
nam	db	?
	ENDS

STRUC	lab
prev	dw	?
val	dw	?
flags	db	?
b_sign	=	7
m_sign	=	80h
m_lnus	=	40h
m_ukp1	=	20h
nam	db	?
	ENDS

STRUC	movt
cod	db	?
vec	dw	?
	ENDS

m_pass	=	80h
m_eofl	=	40h
m_skip	=	20h

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

MACRO	file	_func, _errtx
	mov	bp, offset _errtx
	IF	_func and 0ff00h
	mov	ax, _func
	ELSE
	mov	ah, _func
	ENDIF
	call	xdisk
	ENDM

MACRO	print	_text
	IFNB	<_text>
	mov	dx, offset _text
	ENDIF
	dos	9
	ENDM

MACRO	error	_err
	push	offset _err
	jmp	errln
	ENDM

MACRO	jpass1	_dest
	test	[flags], m_pass
	jz	_dest
	ENDM

MACRO	jpass2	_dest
	test	[flags], m_pass
	jnz	_dest
	ENDM

MACRO	cmd	_oper
_tp	SUBSTR	<_oper>, 4, 2
_tp	CATSTR	<0>, &_tp, <h>
	db	_tp
	IRP	_ct,<3,2,1>
_tp	SUBSTR	<_oper>, _ct, 1
%	db	'&_tp'
	ENDM
_tp	SUBSTR	<_oper>, 6
	dw	_tp
	ENDM

MACRO	opr	_oper
_tp	SUBSTR	<_oper>, 1, 1
	db	_tp
_tp	SUBSTR	<_oper>, 2
_tp	CATSTR	<v_>, _tp
	dw	_tp
	ENDM

;*****************************

	print	hello
	mov	di, 81h
	movzx	cx, [di-1]
	jcxz	usg
	mov	al, ' '
	repe	scasb
	je	usg
	dec	di
	inc	cx
	mov	[fnad], di
	mov	al, '?'
	repne	scasb
	jne	begin

usg:	print	usgtxt
	dos	4c02h

begin:	mov	[origin], 0
	call	ldname

opfile:	mov	bx, offset (icl).nam
	add	bx, [iclen]
	mov	si, di
srex2:	dec	si
	cmp	[byte si], '\'
	je	adex2
	cmp	[byte si], '.'
	je	lvex2
	cmp	si, bx
	ja	srex2
adex2:	mov	[byte di-1], '.'
	mov	eax, 'xsa'
	stosd
lvex2:	call	fopen

main:	test	[flags], m_eofl
	jnz	filend
	mov	bx, [iclen]
	mov	bx, [(icl bx).prev]
	inc	[(icl bx).line]
	inc	[lines]
	mov	di, offset line-1

gline1:	cmp	di, offset line+255
	jnb	linlon
	mov	cx, 1
	lea	dx, [di+1]
	push	dx
	call	fread
	pop	di
	jz	eof
	cmp	[byte di], 0ah
	jne	gline1
	jmp	syntax

eof:	or	[flags], m_eofl
	mov	[word di], 0a0dh

syntax:	mov	si, offset line
	mov	al, [si]
	cmp	al, 0dh
	je	main
	cmp	al, '*'
	je	main
	cmp	al, ';'
	je	main
	cmp	al, '|'
	je	main
	test	[flags], m_skip
	jz	nskip
skip1:	call	get
	cmp	al, ' '
	je	skip2
	cmp	al, 9
	jne	skip1
skip2:	call	space1
	push	offset main
	lodsd
	and	eax, 0dfdfdfh
	cmp	eax, 'TFI'
	je	skift
	cmp	eax, 'SLE'
	je	skels
	cmp	eax, 'DNE'
	je	filend
	cmp	eax, 'FIE'
	jne	skret
	call	p_eif
	dec	[sift]
	jns	skret
	and	[flags], not m_skip
	inc	[sift]	;0
skret:	ret
skift:	call	shlelf
	inc	[sift]
	ret
skels:	call	btself
	cmp	[sift], 0
	jnz	skret
	jmp	fliski

nskip:	mov	[labvec], 0
	cmp	al, ' '
	je	s_cmd
	cmp	al, 9
	je	s_cmd
	jpass2	deflp2
	call	flabel
	jnc	ltwice
	push	si
	mov	si, offset tlabel
	mov	di, [laben]
	mov	[labvec], di
	scasw	;add di, 2
	mov	ax, [origin]
	stosw
	mov	al, m_lnus
	stosb
	mov	cx, dx
	rep	movsb
	mov	ax, di
	cmp	ax, offset t_lab+l_lab-5
	jnb	tmlab
	xchg	ax, [laben]
	stosw
	pop	si
	jmp	s_cmd

ltwice:	error	e_twice
tmlab:	error	e_tlab

deflp2:	call	rlabel
	mov	ax, [pslab]
	mov	[labvec], ax
	add	ax, offset (lab).nam
	add	ax, dx
	mov	[pslab], ax

s_cmd:	lodsb
	cmp	al, ' '
	je	s_cmd
	cmp	al, 9
	je	s_cmd
	cmp	al, 0dh
	jne	s_cmd1
	cmp	[byte high labvec], 0
	je	main
	jmp	uneol
s_cmd1:	dec	si
	lodsw
 	and	ax, 0dfdfh
	xchg	al, ah
	shl	eax, 16
	mov	ah, 0dfh
	and	ah, [si]
	inc	si
	mov	di, offset comtab
	mov	bx, 64*size com
sfcmd1:	mov	al, [(com di+bx).cod]
	cmp	eax, [dword (com di+bx).cod]
	jb	sfcmd3
	jne	sfcmd2

	mov	[cod], al
	call	[(com di+bx).vec]
	call	linend
	jmp	main

sfcmd2:	add	di, bx
	cmp	di, offset comend
	jb	sfcmd3
	sub	di, bx
sfcmd3:	shr	bx, 1
	cmp	bl, 3
	ja	sfcmd1
	mov	bl, 0
	je	sfcmd1
	error	e_inst

filend:	and	[flags], not m_eofl
	call	fclose
	cmp	bx, offset t_icl
	ja	main
	jpass2	fin

	cmp	[elflag], 1
	jne	miseif
	or	[flags], m_pass
	call	putorg
	call	ldname
	mov	si, di
srex1:	dec	si
	cmp	[byte si], '\'
	je	adex1
	cmp	[byte si], '.'
	je	chex1
	cmp	si, offset (icl t_icl).nam
	ja	srex1
	jmp	adex1
chex1:	lea	di, [si+1]
adex1:	mov	[byte di-1], '.'
	mov	[dword di], 'moc'
	mov	dx, offset (icl t_icl).nam
	xor	cx, cx
	file	3ch, e_creat
	mov	[ohand], ax
	mov	ax, 0ffffh
	call	putwor
	mov	[orgvec], offset t_org
	xor	ax, ax
	call	pheadr
	jmp	begin

fin:	mov	bx, [ohand]
	file	3eh, e_writ
	mov	eax, [lines]
	shr	eax, 1
	call	pridec
	print	lintxt
	mov	eax, [bytes]
	call	pridec
	print	byttxt
	mov	ax, [exitcod]
	dos

linlon:	push	offset e_long
	jmp	erron

miseif:	push	offset e_meif
	jmp	erron

; ERROR
errln:	call	ppline
erron:	call	prname
	print	errtxt
	pop	si
	call	prline
	dos	4c02h

; WARNING
warln:	call	ppline
waron:	call	prname
	print	wartxt
	pop	ax
	pop	si
	push	ax
	mov	[byte exitcod], 1
	jmp	prline

prname:	mov	bx, [iclen]
	cmp	bx, offset t_icl
	jna	prnamx
	mov	di, [(icl bx).prev]
	push	di
	lea	dx, [(icl di).nam]
	mov	[byte bx-1], '$'
	print
	mov	dl, ' '
	dos	2
	mov	dl, '('
	dos	2
	pop	bx
	mov	eax, [(icl bx).line]
	call	pridec
	mov	dl, ')'
	dos	2
	mov	dl, ' '
	dos	2
prnamx:	ret

ppline:	mov	si, offset line
prline:	mov	dl, [si]
	dos	2
	inc	si
	cmp	[byte si-1], 0ah
	jne	prline
	ret

; I/O
xdisk:	push	bp
	dos
	jc	erron
	pop	bp
	ret

icler:	push	offset e_icl
	jmp	erron

fopen:	cmp	di, offset t_icl+l_icl-2
	jnb	icler
	mov	bx, [iclen]
	mov	[(icl bx).line], 0
	lea	dx, [(icl bx).nam]
	mov	[(icl di).prev], bx
	mov	[iclen], di
	file	3d00h, e_open
	mov	bx, [iclen]
	mov	bx, [(icl bx).prev]
	mov	[(icl bx).handle], ax
	ret

fread:	mov	ah, 3fh
freacl:	mov	bx, [iclen]
	mov	bx, [(icl bx).prev]
	mov	bx, [(icl bx).handle]
	mov	bp, offset e_read
	call	xdisk
	test	ax, ax
	ret

fclose:	mov	ah, 3eh
	call	freacl
	mov	bx, [iclen]
	mov	bx, [(icl bx).prev]
	mov	[iclen], bx
	ret

putwor:	push	ax
	call	putbyt
	pop	ax
	mov	al, ah
putbyt:	mov	cx, 1
	jpass1	putx
	mov	[oper], al
	mov	dx, offset oper
	mov	bx, [ohand]
	file	40h, e_writ
	inc	[bytes]
putx:	ret

savwor:	inc	[origin]
	inc	[origin]
	jmp	putwor

savbyt:	inc	[origin]
	jmp	putbyt

; Przepisuje nazwe z linii komend
ldname:	mov	si, [fnad]
	mov	di, offset (icl t_icl).nam
ldnam1:	lodsb
	stosb
	cmp	al, 0dh
	jne	ldnam1
	mov	[byte di-1], 0
	ret

; Wyswietla dziesietnie EAX
pridec:	mov	di, offset dectxt+10
	mov	ebx, 10
pride1:	cdq
	div	ebx
	add	dl, '0'
	dec	di
	mov	[di], dl
	test	eax, eax
	jnz	pride1
	mov	dx, di
	print
	ret

; Zapisuje hex AX od [DI]
phword:	push	ax
	mov	al, ah
	call	phbyte
	pop	ax
phbyte:	push	ax
	shr	al, 4
	call	phdig
	pop	ax
	and	al, 0fh
phdig:	cmp	al, 10
	sbb	al, 69h
	das
	stosb
	ret

; Pobiera znak (eol=error)
get:	lodsb
	cmp	al, 0dh
	je	uneol
	ret
uneol:	error	e_uneol

ilchar:	error	e_char

; Omija spacje i tabulatory
spaces:	call	get
	cmp	al, ' '
	je	space1
	cmp	al, 9
	je	space1
	error	e_spac
space1:	call	get
	cmp	al, ' '
	je	space1
	cmp	al, 9
	je	space1
	dec	si
rstret:	ret

; Stwierdza blad, jesli nie spacja, tab lub eol
linend:	lodsb
	cmp	al, 0dh
	je	rstret
	cmp	al, ' '
	je	rstret
	cmp	al, 9
	je	rstret
	error	e_xtra

; Czyta nazwe pliku
rfname:	call	spaces
	mov	di, offset (icl).nam
	add	di, [iclen]
; Czyta lancuch i zapisuje do [di]
rstr:	call	get
	cmp	al, "'"
	je	rstr0
	cmp	al, '"'
	jne	strer
rstr0:	mov	dx, di
	mov	ah, al
rstr1:	call	get
	stosb
	cmp	al, ah
	jne	rstr1
	lodsb
	cmp	al, ah
	je	rstr1
	dec	si
	mov	[byte di-1], 0
	lea	cx, [di-1]
	sub	cx, dx
	jnz	rstret

strer:	error	e_str

; Przepisuje etykiete do tlabel (wyj: dx-dl.etykiety)
rlabel:	mov	di, offset tlabel
	mov	[byte di], 0
rlab1:	lodsb
	cmp	al, '0'
	jb	rlabx
	cmp	al, '9'
	jbe	rlab2
	cmp	al, 'A'
	jb	rlabx
	cmp	al, 'Z'
	jbe	rlab2
	cmp	al, '_'
	je	rlab2
	cmp	al, 'a'
	jb	rlabx
	cmp	al, 'z'
	ja	rlabx
	add	al, 'A'-'a'
rlab2:	stosb
	jmp	rlab1
rlabx:	mov	dx, di
	mov	di, offset tlabel
	cmp	[byte di], 'A'
	jb	ilchar
	sub	dx, di
	dec	si
	ret

; Czyta etykiete i szuka w t_lab
; wyj: dx-dlugosc etykiety
; C=0: znaleziona, bx=adres wpisu
; C=1: nie ma jej
flabel:	call	rlabel
	push	si
	mov	bx, [laben]
flab1:	cmp	bx, offset t_lab
	jb	flabx
	lea	cx, [bx-5]
	mov	bx, [(lab bx).prev]
	sub	cx, bx
	cmp	cx, dx
	jne	flab1
	lea	si, [(lab bx).nam]
	mov	di, offset tlabel
	repe	cmpsb
	jne	flab1
	clc
flabx:	pop	si
	ret

wropar:	error	e_wpar

spaval:	call	spaces
; Czyta wyrazenie i zwraca jego wartosc w [val]
; (C=1 wartosc nieokreslona w pass 1)
getval:	xor	bx, bx
	mov	[ukp1], bh
	push	bx

v_lop:
v_par1:	inc	bh
	call	get
	cmp	al, '['
	je	v_par1
	cmp	al, '('
	je	wropar
	cmp	al, '-'
	je	valuem
	dec	si
	mov	al, '+'
valuem:	mov	bl, al
	xor	eax, eax
	call	get
	cmp	al, '*'
	je	valorg
	cmp	al, "'"
	je	valchr
	cmp	al, '"'
	je	valchr
	cmp	al, '^'
	je	valreg
	mov	bp, -1
	xor	edx, edx
	mov	ecx, 16
	cmp	al, '$'
	je	rdnum3
	mov	cl, 2
	cmp	al, '%'
	je	rdnum3
	mov	cl, 10
	cmp	al, '0'
	jb	ilchar
	cmp	al, '9'
	ja	vlabel

rdnum1:	cmp	al, '9'
	jbe	rdnum2
	and	al, 0dfh
	cmp	al, 'A'
	jb	value0
	add	al, '0'+10-'A'
rdnum2:	sub	al, '0'
	cmp	al, cl
	jnb	value0
	movzx	ebp, al
	lda	edx
	mul	ecx
	add	eax, ebp
	js	toobig
	adc	edx, edx
	jnz	toobig
	sta	edx
rdnum3:	lodsb
	jmp	rdnum1

vlabel:	push	bx
	dec	si
	call	flabel
	jnc	vlabfn
	jpass1	vlukp1
	error	e_undec
vlabfn:	test	[(lab bx).flags], m_ukp1
	jz	vlabkn
	jpass1	vlukp1
	cmp	bx, [pslab]
	jb	vlukp1
	error	e_fref
vlukp1:	mov	[ukp1], 0ffh
vlabkn:	bt	[word (lab bx).flags], b_sign
	sbb	eax, eax
	mov	ax, [(lab bx).val]
	pop	bx
	jmp	value1

valorg:	mov	ax, [origin]
	jmp	value1

valchr:	mov	dl, al
	call	get
	cmp	al, dl
	jne	valch1
	lodsb
	cmp	al, dl
	jne	strer
valch1:	cmp	dl, [si]
	jne	strer
	inc	si
	cmp	[byte si], '*'
	jne	value1
	inc	si
	xor	al, 80h
	jmp	value1

valreg:	call	get
	cmp	al, '4'
	ja	ilchar
	sub	al, '0'
	jb	ilchar
	add	al, 0d0h
	mov	ah, al
	call	get
	cmp	al, '9'
	jbe	valre1
	and	al, 0dfh
	cmp	al, 'A'
	jb	ilchar
	add	al, '0'+10-'A'
valre1:	sub	al, '0'
	cmp	al, 0fh
	ja	ilchar	
	cmp	ah, 0d1h
	jne	value1
	sub	ax, 0f0h
valre2:	jmp	value1

value0:	dec	si
	test	bp, bp
	js	ilchar
	lda	edx
value1:	cmp	bl, '-'
	jne	value2
	neg	eax
value2:	push	eax
v_par2:	dec	bh
	js	mbrack
	lodsb
	cmp	al, ']'
	je	v_par2

	mov	ah, [si]
	mov	di, offset opert2
	mov	cx, noper2
	repne	scasw
	je	foper2
	mov	cx, noper1
	repne	scasb
	je	foper1
	test	bh, bh
	jnz	mbrack
	dec	si
	mov	di, offset opert1
foper1:	sub	di, offset opert1
	jmp	goper
foper2:	inc	si
	sub	di, offset opert2
	shr	di, 1
	add	di, noper1
goper:	lea	ax, [di+operpa]
	add	di, di
	add	di, ax
	mov	bl, [di]
	mov	bp, [di+1]
	pop	eax
v_com:	pop	cx
	cmp	cx, bx
	jb	v_xcm
	pop	ecx
	xchg	eax, ecx
	pop	dx
	push	offset v_com
	push	dx
	ret
v_xcm:	cmp	bl, 1
	jbe	v_xit
	push	cx bp eax bx
	jmp	v_lop
v_xit:	mov	[dword val], eax
	cmp	[ukp1], 1
	cmc
	jc	v_ret
	cmp	eax, 10000h
	cmc
	jnb	v_ret
	cmp	eax, -0ffffh
	jb	orange
	ret

brange:	cmp	eax, 100h
	jb	v_ret
	cmp	eax, -0ffh
	jb	orange
	ret

spauns:	call	spaces
getuns:	call	getval
	jc	v_ret
	test	eax, eax
	jns	v_ret
orange:	error	e_range

mbrack:	error	e_brack

toobig:	error	e_nbig

v_add:	add	eax, ecx
	jmp	v_cov

v_sub:	sub	eax, ecx
v_cov:	jno	v_ret
oflow:	error	e_over

div0:	error	e_div0

v_mul:	mov	edx, ecx
	xor	ecx, eax
	imul	edx
	test	ecx, ecx
	js	v_mu1
	test	edx, edx
	jnz	oflow
	test	eax, eax
	js	oflow
	ret
v_mu1:	inc	edx
	jnz	oflow
	test	eax, eax
	jns	oflow
	ret

v_div:	jecxz	div0
	cdq
	idiv	ecx
	ret

v_mod:	jecxz	div0
	cdq
	idiv	ecx
	sta	edx
v_ret:	ret

v_sln:	neg	ecx
v_sal:	test	ecx, ecx
	js	v_srn
	jz	v_ret
	cmp	ecx, 20h
	jb	v_sl1
	test	eax, eax
	jnz	oflow
	ret
v_sl1:	add	eax, eax
	jo	oflow
	loop	v_sl1
	ret

v_srn:	neg	ecx
v_sar:	test	ecx, ecx
	js	v_sln
	cmp	ecx, 20h
	jb	v_sr1
	mov	cl, 1fh
v_sr1:	sar	eax, cl
	ret

v_and:	and	eax, ecx
	ret

v_or:	or	eax, ecx
	ret

v_xor:	xor	eax, ecx
	ret

v_equ:	cmp	eax, ecx
	je	v_one
v_zer:	xor	eax, eax
	ret
v_one:	mov	eax, 1
	ret

v_neq:	cmp	eax, ecx
	jne	v_one
	jmp	v_zer

v_les:	cmp	eax, ecx
	jl	v_one
	jmp	v_zer

v_grt:	cmp	eax, ecx
	jg	v_one
	jmp	v_zer

v_leq:	cmp	eax, ecx
	jle	v_one
	jmp	v_zer

v_geq:	cmp	eax, ecx
	jge	v_one
	jmp	v_zer

v_anl:	jecxz	v_zer
	test	eax, eax
	jz	v_ret
	jmp	v_one

v_orl:	or	eax, ecx
	jz	v_ret
	jmp	v_one

; Pobiera operand rozkazu i rozpoznaje tryb adresowania
getadr:	call	spaces
	lodsb
	xor	dx, dx
	cmp	al, '@'
	je	getadx
	cmp	al, '#'
	je	getaim
	cmp	al, '<'
	je	getaim
	cmp	al, '>'
	je	getaim
	mov	dl, 8
	cmp	al, '('
	je	getad1
	dec	si
	lodsw
	and	al, 0dfh
	mov	dl, 2
	cmp	ax, ':A'
	je	getad1
	inc	dx
	cmp	ax, ':Z'
	je	getad1
	dec	si
	dec	si
	xor	dx, dx
	
getad1:	push	dx
	call	getuns
	sbb	al, al
	jnz	getad2
	mov	al, [byte high val]
getad2:	pop	dx
	cmp	dl, 8
	jae	getaid
	cmp	dl, 2
	jae	getad3
	cmp	al, 1
	adc	dl, 2
getad3:	lodsw
	and	ah, 0dfh
	mov	bl, 2
	cmp	ax, 'X,'
	je	getabi
	mov	bl, 4
	cmp	ax, 'Y,'
	je	getabi
	dec	si
	dec	si
	jmp	getadx
getabi:	add	dl, bl
getaxt:	lodsb
	cmp	al, '+'
	je	getabx
	inc	bx
	cmp	al, '-'
	je	getabx
	dec	si
	jmp	getadx
getabx:	mov	dh, bl
getadx:	lda	dx
	mov	[word amod], ax
	ret

getaim:	cmp	al, '<'
	pushf
	call	getval
	popf
	jb	getai2
	je	getai1
	mov	al, ah
getai1:	movzx	eax, al
	mov	[dword val], eax
getai2:	mov	dx, 1
	jmp	getadx

getaid:	lodsb
	cmp	al, ','
	je	getaix
	cmp	al, ')'
	jne	mparen
	lodsw
	mov	dx, 709h
	cmp	ax, '0,'
	je	getadx
	xor	dh, dh
	mov	bl, 4
	and	ah, 0dfh
	cmp	ax, 'Y,'
	je	getaxt
	inc	dx
	dec	si
	dec	si
	jmp	getadx
getaix:	lodsw
	mov	dh, 6
	cmp	ax, ')0'
	je	getadx
	xor	dh, dh
	and	al, 0dfh
	cmp	ax, ')X'
	je	getadx
	jmp	ilchar
	
p_imp	=	savbyt

p_ads:	call	getadr
	mov	al, [cod]
	call	savbyt
	mov	al, 60h
	cmp	[cod], 18h
	je	p_as1
	mov	al, 0e0h
p_as1:	mov	[cod], al
	jmp	p_ac1

p_acc:	call	getadr
p_ac1:	mov	ax, [word amod]
	cmp	al, 7
	jne	acc1
	dec	[amod]
acc1:	cmp	ah, 6
	jb	acc3
	mov	ax, 0a2h
	je	acc2
	mov	al, 0a0h
acc2:	call	savwor
acc3:	mov	al, [amod]
	mov	bx, offset acctab
	xlat
	test	al, al
	jz	ilamod
	or	al, [cod]
	cmp	al, 89h
	jne	putsfx
ilamod:	error	e_amod

p_srt:	call	getadr
	cmp	al, 6
	jnb	ilamod
	cmp	al, 1
	je	ilamod
	mov	bx, offset srttab
	xlat
	or	al, [cod]
	cmp	al, 0c0h
	je	ilamod
	cmp	al, 0e0h
	je	ilamod
putsfx:	call	putcmd
	mov	al, [amod+1]
	mov	bx, offset sfxtab
	xlat
	test	al, al
	jnz	savbyt
putret:	ret
	
p_inw:	call	getadr
	cmp	al, 6
	jnb	ilamod
	sub	al, 2
	jb	ilamod
	mov	bx, offset inwtab
	xlat
	push	ax
	call	putcmd
	inc	[val]
	mov	ax, 03d0h
	test	[amod], 1
	jz	p_iw1
	dec	ah
p_iw1:	call	savwor
	pop	ax
	jmp	putsfx

p_ldi:	call	getadr
p_ld1:	mov	al, [amod]
	cmp	al, 1
	jb	ilamod
	cmp	al, 4
	jb	ldi1
	and	al, 0feh
	xor	al, [cod]
	cmp	al, 0a4h
	jne	ilamod
	mov	al, [amod]
ldi1:	mov	bx, offset lditab
	xlat
putcod:	or	al, [cod]
	jmp	putsfx

putcmd:	call	savbyt
	mov	al, [amod]
	mov	bx, offset lentab
	xlat
	cmp	al, 2
	jb	putret
	mov	eax, [dword val]
	jne	savwor
	jpass1	putcm1
	call	brange
putcm1:	jmp	savbyt

p_sti:	call	getadr
p_st1:	mov	al, [amod]
	cmp	al, 2
	jb	ilamod
	je	cod8
	cmp	al, 3
	je	cod0
	and	al, 0feh
	xor	al, [cod]
	cmp	al, 80h
	jne	ilamod
	or	[amod], 1
	mov	al, 10h
	jmp	putcod
cod8:	mov	al, 8
	jmp	putcod
cod0:	xor	al, al
	jmp	putcod

p_cpi:	call	getadr
	cmp	al, 1
	jb	ilamod
	cmp	al, 4
	jnb	ilamod
	cmp	al, 2
	jb	cod0
	je	cod8
	mov	al, 4
	jmp	putcod

p_bra:	call	getadr
	jpass1	bra1
	mov	ax, [val]
	sub	ax, [origin]
	add	ax, 7eh
	test	ah, ah
	jnz	toofar
	add	al, 80h
	mov	[byte val], al
	mov	al, [cod]
bra1:	call	savbyt
	mov	al, [byte val]
	jmp	savbyt

toofar:	cmp	ax, 8080h
	jae	toofa1
	sub	ax, 0ffh
	neg	ax
toofa1:	neg	ax
	mov	di, offset brout
	call	phword
	error	e_bra

p_jsr:	call	getadr
	mov	al, 20h
	jmp	p_abs

p_bit:	call	getadr
	cmp	al, 2
	mov	al, 2ch
	je	putcmd
	cmp	[amod], 3
	jne	ilamod
	mov	al, 24h
	jmp	putcmd

p_juc:	call	getadr
	mov	al, [cod]
	mov	ah, 3
	call	savwor
	jmp	p_jp1

p_jmp:	call	getadr
p_jp1:	cmp	[amod], 10
	je	chkbug
	jpass1	p_jpu
	cmp	[cod], 4ch
	je	p_jpu
	mov	ax, [val]
	sub	ax, [origin]
	add	ax, 80h
	test	ah, ah
	jnz	p_jpu
	push	si
	push	offset w_bras
	call	warln
	pop	si
p_jpu:	mov	al, 4ch
p_abs:	and	[amod], 0feh
	cmp	[amod], 2
	je	p_jpp
	jmp	ilamod
chkbug:	jpass1	p_jid
	cmp	[byte val], 0ffh
	jne	p_jid
	push	si
	push	offset w_bugjp
	call	warln
	pop	si
p_jid:	mov	al, 6ch
p_jpp:	jmp	putcmd

getops:	call	getadr
	mov	di, offset op1
	call	stop
	push	[word ukp1]
	call	getadr
	pop	[word ukp1]
	mov	[tempsi], si
	mov	di, offset op2
	call	stop
	movzx	bx, [cod]
	add	bx, offset movtab
ldop1:	mov	si, offset op1
ldop:	lodsd
	mov	[dword val], eax
	lodsw
	mov	[word amod], ax
	ret
stop:	mov	eax, [dword val]
	stosd
	mov	ax, [word amod]
	stosw
	ret

mcall1:	mov	al, [(movt bx).cod]
	mov	[cod], al
	push	bx
	call	[(movt bx).vec]
	pop	bx
	ret

mcall2:	mov	al, [(movt bx+3).cod]
	mov	[cod], al
	push	bx
	call	[(movt bx+3).vec]
	pop	bx
	ret

p_mvs:	call	getops
	call	mcall1
	mov	si, offset op2
	call	ldop
p_mvx:	call	mcall2
	mov	si, [tempsi]
	ret

p_mws:	call	getops
	mov	ax, [word amod]
	cmp	ax, 8
	jae	ilamod
	cmp	al, 1
	jne	p_mw1
	mov	[byte high val], 0
	mov	[word val+2], 0
p_mw1:	call	mcall1
	mov	si, offset op2
	call	ldop
	cmp	[word amod], 8
	jae	ilamod
	call	mcall2
	call	ldop1
	cmp	[amod], 1
	je	p_mwi
	inc	[val]
	jmp	p_mw2
p_mwi:	movzx	eax, [byte high val]
	cmp	[ukp1], ah	;0
	jnz	p_mwh
	cmp	al, [byte val]
	je	p_mw3
p_mwh:	mov	[dword val], eax
p_mw2:	call	mcall1
p_mw3:	mov	si, offset op2
	call	ldop
	inc	[val]
	jmp	p_mvx

p_opt:	error	e_opt

p_ert:	call	spaval
	jpass1	equret
	test	eax, eax
	jz	equret
	error	e_user

p_equ:	mov	di, [labvec]
	test	di, di
	jz	nolabl
	mov	[(lab di).val], 0
	and	[(lab di).flags], not m_sign
	call	spaval
	mov	di, [labvec]
	jnc	equ1
	or	[(lab di).flags], m_ukp1
equ1:	mov	[(lab di).val], ax
	test	eax, eax
	jns	equret
	or	[(lab di).flags], m_sign
equret:	ret

nolabl:	error	e_label

p_org:	call	spauns
	jc	unknow
p_org1:	jpass2	org1
	call	putorg
	stc
org1:	mov	ax, [val]
	mov	[origin], ax
	jc	pheart
pheadr:	mov	bx, [orgvec]
	cmp	ax, [bx]
	je	pheart
	call	putwor
	mov	bx, [orgvec]
	mov	ax, [bx]
	dec	ax
	call	putwor
pheart:	add	[orgvec], 2
	ret

putorg:	mov	bx, [orgvec]
	cmp	bx, offset t_org+l_org-2
	jnb	tmorgs
	mov	ax, [origin]
	mov	[bx], ax
	ret

tmorgs:	error	e_orgs

p_rui:	mov	ah, 2
	mov	[val], ax
	call	p_org1
	call	spauns
	mov	ax, [val]
	jmp	savwor

valuco:	call	getval
	jc	unknow
	call	get
	cmp	al, ','
	jne	badsin
	mov	ax, [val]
	ret
badsin:	error	e_sin

p_dta:	call	spaces
dta1:	call	get
	and	al, 0dfh
	mov	[cod], al
	cmp	al, 'A'
	je	dtan1
	cmp	al, 'B'
	je	dtan1
	cmp	al, 'L'
	je	dtan1
	cmp	al, 'H'
	je	dtan1
	cmp	al, 'C'
	je	dtat1
	cmp	al, 'D'
	je	dtat1
	cmp	al, 'R'
	je	dtar1
	jmp	ilchar

dtan1:	lodsb
	cmp	al, '('
	jne	mparen

dtan2:	lodsd
	and	eax, 0ffdfdfdfh
	cmp	eax, '(NIS'
	jne	dtansi
	call	valuco
	mov	[sinadd], ax
	call	valuco
	mov	[sinamp], ax
	call	getuns
	jc	unknow
	mov	ax, [val]
	test	ax, ax
	jz	badsin
	mov	[sinsiz], ax
	mov	[sinmin], 0
	dec	ax
	mov	[sinmax], ax
	call	get
	cmp	al, ')'
	je	presin
	cmp	al, ','
	jne	badsin
	call	valuco
	test	eax, eax
	js	badsin
	mov	[sinmin], ax
	call	getuns
	jc	unknow
	mov	ax, [val]
	cmp	ax, [sinmin]
	jb	badsin
	mov	[sinmax], ax
	lodsb
	cmp	al, ')'
	jne	mparen
presin:	finit
	fldpi
	fld	st
	faddp	st(1), st
	fidiv	[sinsiz]
gensin:	fild	[sinmin]
	fmul	st, st(1)
	fsin
	fimul	[sinamp]
	fistp	[val]
	inc	[sinmin]
	mov	ax, [sinadd]
	add	[val], ax
	jmp	dtasto
	
dtansi:	sub	si, 4
	call	getval
dtasto:	jpass1	dtan3
	mov	al, [cod]
	cmp	al, 'B'
	je	dtanb
	cmp	al, 'L'
	je	dtanl
	cmp	al, 'H'
	je	dtanh
	mov	ax, [val]
	call	savwor
	jmp	dtanx

dtanb:	mov	eax, [dword val]
	call	brange
	jmp	dtans

dtanl:	mov	al, [byte low val]
	jmp	dtans

dtanh:	mov	al, [byte high val]

dtans:	call	savbyt
	jmp	dtanx

dtan3:	cmp	[cod], 'A'+1
	adc	[origin], 1
	
dtanx:	mov	ax, [sinmin]
	cmp	ax, [sinmax]
	jbe	gensin
	lodsb
	cmp	al, ','
	je	dtan2
	cmp	al, ')'
	je	dtanxt

mparen:	error	e_paren

unknow:	error	e_uknow

dtat1:	mov	di, offset tlabel
	call	rstr
	lodsb
	mov	ah, 80h
	cmp	al, '*'
	je	dtat2
	dec	si
	xor	ah, ah
dtat2:	push	si
	mov	si, dx
dtatm:	lodsb
	xor	al, ah
	cmp	[cod], 'D'
	jne	ascinx
	mov	dl, 60h
	and	dl, al
	jz	ascin1
	cmp	dl, 60h
	je	ascinx
	sub	al, 60h
ascin1:	add	al, 40h
ascinx:	push	ax cx si
	call	savbyt
	pop	si cx ax
	loop	dtatm
	pop	si
dtanxt:	lodsb
	cmp	al, ','
	je	dta1
	dec	si
	ret

dtar1:	lodsb
	cmp	al, '('
	jne	mparen
dtar2:	xor	bx, bx
	xor	edx, edx
	xor	cx, cx
	call	getsgn
dreal1:	call	getdig
	jnc	dreal2
	cmp	al, '.'
	je	drealp
	test	bh, bh
	jnz	drealz
	jmp	ilchar
dreal2:	mov	bh, 1
	test	al, al
	jz	dreal1
	dec	cx
dreal3:	inc	cx
	call	putdig
	call	getdig
	jnc	dreal3
	cmp	al, '.'
	je	drealp
	and	al, 0dfh
	cmp	al, 'E'
	jne	drealf
dreale:	call	getsgn
	call	getdig
	jc	ilchar
	mov	ah, al
	call	getdig
	jnc	dreal4
	shr	ax, 8
dreal4:	aad
	add	di, di
	jnc	drealn
	neg	ax
drealn:	add	cx, ax
	jmp	drealf
dreal5:	test	edx, edx
	jnz	dreal9
	test	bl, bl
	jnz	dreal9
	dec	cx
dreal9:	call	putdig
drealp:	call	getdig
	jnc	dreal5
	and	al, 0dfh
	cmp	al, 'E'
	je	dreale
drealf:	test	edx, edx
	jnz	drealx
	test	bl, bl
	jnz	drealx
drealz:	xor	ax, ax
	xor	edx, edx
	jmp	dreals
drealx:	add	cx, 80h
	cmp	cx, 20h
	js	drealz
	cmp	cx, 0e2h
	jnb	toobig
	add	di, di
	rcr	cl, 1
	mov	al, 10h
	jc	dreal7
	cmp	bl, al
	mov	al, 1
	jb	dreal7
	shrd	edx, ebx, 4
	shr	bl, 4
	jmp	dreal8
dreal6:	shld	ebx, edx, 4
	shl	edx, 4
dreal7:	cmp	bl, al
	jb	dreal6
dreal8:	lda	cx
	mov	ah, bl
dreals:	rol	edx, 16
	push	edx
	call	savwor
	pop	ax
	xchg	ah, al
	call	savwor
	pop	ax
	xchg	ah, al
	call	savwor
	dec	si
	lodsb
	cmp	al, ','
	je	dtar2
	cmp	al, ')'
	jne	mparen
	jmp	dtanxt

putdig:	cmp	bl, 10h
	jnb	rlret
	shld	ebx, edx, 4
	shl	edx, 4
	add	dl, al
	ret

getsgn:	call	get
	cmp	al, '-'
	stc
	je	sgnret
	cmp	al, '+'
	clc
	je	sgnret
	dec	si
sgnret:	rcr	di, 1
rlret:	ret

getdig:	call	get
	cmp	al, '0'
	jb	rlret
	cmp	al, '9'+1
	cmc
	jb	rlret
	sub	al, '0'
	ret

p_icl:	call	rfname
	pop	ax
	call	linend
	jmp	opfile

p_ins:	call	rfname
	call	fopen
	push	si
p_in1:	mov	cx, 256
	mov	dx, offset tlabel
	call	fread
	jz	p_in2
	add	[origin], ax
	cwde
	mov	bx, [iclen]
	mov	bx, [(icl bx).prev]
	add	[(icl bx).line], eax
	jpass1	p_in1
	add	[bytes], eax
	sta	cx
	mov	bx, [ohand]
	mov	dx, offset tlabel
	file	40h, e_writ
	jmp	p_in1
p_in2:	call	fclose
	pop	si
	ret

p_end:	pop	ax
	call	linend
	jmp	filend

shlelf:	shl	[elflag], 1
	jnc	cndret
	error	e_tmift

btself:	bts	[elflag], 0
	jnc	cndret
	error	e_eifex

p_ift:	call	spaval
	jc	unknow
	call	shlelf
	test	eax, eax
	jz	fliski
cndret:	ret

p_els:	cmp	[elflag], 1
	je	misift
	call	btself
fliski:	xor	[flags], m_skip
	ret

p_eif:	shr	[elflag], 1
	jnz	cndret
misift:	error	e_mift

; addressing modes:
; 0-@ 1-# 2-A 3-Z 4-A,X 5-Z,X 6-A,Y 7-Z,Y 8-(Z,X) 9-(Z),Y 10-(A)
lentab	db	1,2,3,2,3,2,3,2,2,2,3
acctab	db	0,9,0dh,5,1dh,15h,19h,19h,1,11h,0
srttab	db	0ah,0,0eh,6,1eh,16h
lditab	db	0,0,0ch,4,1ch,14h,1ch,14h
inwtab	db	0eeh,0e6h,0feh,0f6h
; pseudo-adr modes: 2-X+ 3-X- 4-Y+ 5-Y- 6-,0) 7-),0
sfxtab	db	0,0,0e8h,0cah,0c8h,088h,0,0

movtab	movt	<0a0h,p_ac1>,<080h,p_ac1>
	movt	<0a2h,p_ld1>,<086h,p_st1>
	movt	<0a0h,p_ld1>,<084h,p_st1>

comtab:	cmd	ADC60p_acc
	cmd	ADD18p_ads
	cmd	AND20p_acc
	cmd	ASL00p_srt
	cmd	BCC90p_bra
	cmd	BCSb0p_bra
	cmd	BEQf0p_bra
	cmd	BIT2cp_bit
	cmd	BMI30p_bra
	cmd	BNEd0p_bra
	cmd	BPL10p_bra
	cmd	BRK00p_imp
	cmd	BVC50p_bra
	cmd	BVS70p_bra
	cmd	CLC18p_imp
	cmd	CLDd8p_imp
	cmd	CLI58p_imp
	cmd	CLVb8p_imp
	cmd	CMPc0p_acc
	cmd	CPXe0p_cpi
	cmd	CPYc0p_cpi
	cmd	DECc0p_srt
	cmd	DEXcap_imp
	cmd	DEY88p_imp
	cmd	DTA00p_dta
	cmd	EIF00p_eif
	cmd	ELS00p_els
	cmd	END00p_end
	cmd	EOR40p_acc
	cmd	EQU00p_equ
	cmd	ERT00p_ert
	cmd	ICL00p_icl
	cmd	IFT00p_ift
	cmd	INCe0p_srt
	cmd	INIe2p_rui
	cmd	INS00p_ins
	cmd	INW00p_inw
	cmd	INXe8p_imp
	cmd	INYc8p_imp
	cmd	JCCb0p_juc
	cmd	JCS90p_juc
	cmd	JEQd0p_juc
	cmd	JMI10p_juc
	cmd	JMP4cp_jmp
	cmd	JNEf0p_juc
	cmd	JPL30p_juc
	cmd	JSR20p_jsr
	cmd	JVC70p_juc
	cmd	JVS50p_juc
	cmd	LDAa0p_acc
	cmd	LDXa2p_ldi
	cmd	LDYa0p_ldi
	cmd	LSR40p_srt
	cmd	MVA00p_mvs
	cmd	MVX06p_mvs
	cmd	MVY0cp_mvs
	cmd	MWA00p_mws
	cmd	MWX06p_mws
	cmd	MWY0cp_mws
	cmd	NOPeap_imp
	cmd	OPT00p_opt
	cmd	ORA00p_acc
	cmd	ORG00p_org
	cmd	PHA48p_imp
	cmd	PHP08p_imp
	cmd	PLA68p_imp
	cmd	PLP28p_imp
	cmd	ROL20p_srt
	cmd	ROR60p_srt
	cmd	RTI40p_imp
	cmd	RTS60p_imp
	cmd	RUNe0p_rui
	cmd	SBCe0p_acc
	cmd	SEC38p_imp
	cmd	SEDf8p_imp
	cmd	SEI78p_imp
	cmd	STA80p_acc
	cmd	STX86p_sti
	cmd	STY84p_sti
	cmd	SUB38p_ads
	cmd	TAXaap_imp
	cmd	TAYa8p_imp
	cmd	TSXbap_imp
	cmd	TXA8ap_imp
	cmd	TXS9ap_imp
	cmd	TYA98p_imp
comend:

operpa:	opr	1ret
	opr	5add
	opr	5sub
	opr	6mul
	opr	6div
	opr	6mod
	opr	6and
	opr	5or
	opr	5xor
	opr	4equ
	opr	4les
	opr	4grt
	opr	6sal
	opr	6sar
	opr	4leq
	opr	4geq
	opr	4neq
	opr	4neq
	opr	3anl
	opr	2orl

opert2	db	'<<>><=>=<>!=&&||'
noper2	=	($-opert2)/2
opert1	db	'+-*/%&|^=<>'
noper1	=	$-opert1

hello	db	'X-Assembler 1.7 by Fox/Taquart',eot
usgtxt	db	'Give a source filename. Default extension is .ASX.',eol
	db	'Object file will be written with .COM extension.',eot
lintxt	db	' lines assembled',eot
byttxt	db	' bytes written',eot
dectxt	db	10 dup(' '),'$'
wartxt	db	'WARNING: $'
w_bugjp	db	'Buggy indirect jump',eol
w_bras	db	'Branch would be sufficient',eol
errtxt	db	'ERROR: $'
e_open	db	'Can''t open file',eol
e_read	db	'Disk read error',eol
e_creat	db	'Can''t write destination',eol
e_writ	db	'Disk write error',eol
e_icl	db	'Too many files nested',eol
e_long	db	'Line too long',eol
e_uneol	db	'Unexpected eol',eol
e_char	db	'Illegal character',eol
e_twice	db	'Label declared twice',eol
e_inst	db	'Illegal instruction',eol
e_nbig	db	'Number too big',eol
e_xtra	db	'Extra characters on line',eol
e_label	db	'Label name required',eol
e_str	db	'String error',eol
e_orgs	db	'Too many ORGs',eol
e_paren	db	'Need parenthesis',eol
e_tlab	db	'Too many labels',eol
e_amod	db	'Illegal addressing mode',eol
e_bra	db	'Branch out of range by $'
brout	db	'     bytes',eol
e_sin	db	'Bad or missing sinus parameter',eol
e_spac	db	'Space expected',eol
e_opt	db	'OPT directive not supported',eol
e_over	db	'Arithmetic overflow',eol
e_div0	db	'Divide by zero',eol
e_range	db	'Value out of range',eol
e_uknow	db	'Label not defined before',eol
e_undec	db	'Undeclared label',eol
e_fref	db	'Illegal forward reference',eol
e_wpar	db	'Use square brackets instead',eol
e_brack	db	'Not matching brackets',eol
e_user	db	'User error',eol
e_tmift	db	'Too many IFTs nested',eol
e_eifex	db	'EIF expected',eol
e_mift	db	'Missing IFT',eol
e_meif	db	'Missing EIF',eol

exitcod	dw	4c00h
flags	db	0
lines	dd	0
bytes	dd	0
iclen	dw	t_icl
laben	dw	t_lab-2
pslab	dw	t_lab-2
orgvec	dw	t_org
sift	dw	0
elflag	dd	1
sinmin	dw	1
sinmax	dw	0
sinadd	dw	?
sinamp	dw	?
sinsiz	dw	?
ohand	dw	?
val	dw	?,?
amod	db	?,?
ukp1	db	?,?
oper	db	?
cod	db	?
origin	dw	?
labvec	dw	?
fnad	dw	?
tempsi	dw	?
op1	dd	?
	dw	?
op2	dd	?
	dw	?

line	db	258 dup(?)
tlabel	db	256 dup(?)
t_icl	db	l_icl dup(?)
t_org	db	l_org dup(?)
t_lab	db	l_lab dup(?)

	ENDS
	END	start