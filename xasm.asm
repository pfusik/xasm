; X-Assembler

	IDEAL
	P386
	MODEL	TINY
	CODESEG

; comment out to disable
SET_WIN_TITLE	=	1

compak	=	1d00h

l_icl	=	1024
l_org	=	4096
l_lab	=	48000

STRUC	com
c_code	db	?
c_flag	db	?
c_name	db	?,?,?
c_vec	dw	?
	ENDS

STRUC	icl
prev	dw	?
handle	dw	?
line	dd	?
flags	db	?
m_eofl	=	1
nam	db	?
	ENDS

STRUC	lab
l_val	dw	?
flags	db	?
b_sign	=	7
m_sign	=	80h
m_lnus	=	40h
m_ukp1	=	20h
len	db	?
nam	db	?
	ENDS

STRUC	movt
m_code	db	?
m_vec	dw	?
	ENDS

;[flags]
m_pass	=	1
m_norg	=	2
m_rorg	=	4
m_rqff	=	8
b_hdr	=	4
m_hdr	=	10h
m_pair	=	20h
m_repa	=	40h
b_skit	=	7
m_skit	=	80h
b_enve	=	8
m_enve	=	100h
m_wobj	=	200h
m_times	=	400h
m_first	=	800h
b_skif	=	12
m_skif	=	1000h
b_repl	=	13
m_repl	=	2000h

;[swits]
m_swc	=	1
m_swe	=	2
m_swi	=	4
m_swl	=	8
b_swn	=	4
m_swn	=	10h
m_swo	=	20h
m_sws	=	40h
m_swt	=	80h
m_swu	=	100h

;[flist]
m_lsti	=	4
m_lstl	=	8
m_lsto	=	10h
m_lsts	=	m_lsto+m_lstl+m_lsti

nhand	=	-1	;null handle
cr	equ	13
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
	IFNB	<_errtx>
	mov	[errmsg], offset _errtx
	ENDIF
	IF	_func and 0ff00h
	mov	ax, _func
	ELSE
	mov	ah, _func
	ENDIF
	call	xdisk
	ENDM

MACRO	jfile	_func, _errtx
	IFNB	<_errtx>
	mov	[errmsg], offset _errtx
	ENDIF
	IF	_func and 0ff00h
	mov	ax, _func
	ELSE
	mov	ah, _func
	ENDIF
	jmp	xdisk
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

MACRO	testfl	_mask
	testflag [flags], _mask
	ENDM

MACRO	resfl	_mask
	maskflag [flags], not (_mask)
	ENDM

MACRO	setfl	_mask
	setflag	[flags], _mask
	ENDM

MACRO	testsw	_mask
	testflag [swits], _mask
	ENDM

MACRO	setsw	_mask
	setflag	[swits], _mask
	ENDM

MACRO	jpass1	_dest
	testflag [flags], m_pass
	jz	_dest
	ENDM

MACRO	jpass2	_dest
	testflag [flags], m_pass
	jnz	_dest
	ENDM

MACRO	jopcod	_dest
	cmp	bp, offset var
	jne	_dest
	ENDM

MACRO	jnopcod	_dest
	cmp	bp, offset var
	je	_dest
	ENDM

MACRO	cmd	_oper
_tp	SUBSTR	<_oper>, 4, 4
_tp	CATSTR	<0>, &_tp, <h>
	dw	_tp
	IRP	_ct,<3,2,1>
_tp	SUBSTR	<_oper>, _ct, 1
%	db	'&_tp'
	ENDM
_tp	SUBSTR	<_oper>, 8
	dw	_tp
	ENDM

MACRO	opr	_oper
_tp	SUBSTR	<_oper>, 1, 1
	db	_tp
_tp	SUBSTR	<_oper>, 2
_tp	CATSTR	<v_>, _tp
	dw	_tp
	ENDM

MACRO	undata
	db	6 dup(?)
lstnum	db	5 dup(?)
lstspa	db	?
lstorg	db	26 dup(?)
line	db	258 dup(?)
tlabel	db	256 dup(?)
obuf	db	128 dup(?)
obufen:
objnam	db	128 dup(?)
lstnam	db	128 dup(?)
tabnam	db	128 dup(?)
t_icl	db	l_icl dup(?)
t_org	db	l_org dup(?)
	ENDM

;*****************************

zero	db	100h dup(?)
start:
IFDEF	compak
	undata
	db	compak+start-$ dup(?)
ENDIF

	ifdef	SET_WIN_TITLE
	mov	di, offset hello
	mov	ax, 168eh
	xor	dx, dx
	int	2fh
	mov	[titfin], ' '
	endif
	print	hello
	mov	di, 81h
	movzx	cx, [di-1]
	jcxz	usg		; brak parametrow - usage
	mov	al, ' '
	repe	scasb
	je	usg		; same spacje - usage
	dec	di
	inc	cx
	mov	si, di
	mov	al, '?'
	repne	scasb
	jne	begin		; '?' - usage

usg:	print	usgtxt		; usage - instrukcja
	dos	4c03h

begin:	lodsb			; pobierz nazwe
	cmp	al, '/'
	je	usg		; najpierw musi byc nazwa
	mov	di, offset (icl t_icl).nam+1
	lea	dx, [di-1]
	xor	ah, ah
	mov	[tabnam], ah	; nie ma nazwy tabeli symboli
dinam	equ	di-t_icl-offset (icl).nam
mnam1:	dec	di		; zapisz do t_icl.nam, ...
	mov	[objnam+dinam], ax	; ... objnam, ...
	mov	[lstnam+dinam], ax	; ... lstnam
	stosw
	lodsb
	cmp	al, ' '
	je	mnam2
	cmp	al, '/'
	je	mnam2
	cmp	al, 0dh
	jne	mnam1
mnam2:	call	adasx		; doczep .ASX
	mov	[fslen], di
chex1:	dec	di
	cmp	[byte di], '.'
	jne	chex1
	mov	[byte objnam+dinam], '.'	; doczep .OBX
	mov	[dword objnam+dinam+1], 'XBO'
	mov	[byte lstnam+dinam], '.'	; doczep .LST
	mov	[dword lstnam+dinam+1], 'TSL'

gsw0:	dec	si
gsw1:	lodsb			; pobierz switche
	cmp	al, ' '
	je	gsw1		; pomin spacje
	cmp	al, 0dh
	je	gswx
	cmp	al, '/'
	jne	usg		; musi byc '/'
	lodsb
	and	al,0dfh		; mala litera -> duza
	mov	di, offset swilet
	mov	cx, 9
	repne	scasb
neusg:	jne	usg		; nie ma takiego switcha
	bts	[swits], cx	; sprawdz bit i ustaw
	jc	usg		; juz byl taki
	mov	di, offset lstnam
	mov	ecx, 'TSL'
	cmp	al, 'L'
	je	gsw2		; /L
	mov	di, offset tabnam
	mov	ecx, 'BAL'
	cmp	al, 'T'
	je	gsw2		; /T
	cmp	al, 'O'
	jne	gsw1		; switch bez parametru
	cmp	[byte si], ':'
	jne	neusg		; /O wymaga ':'
	mov	di, offset objnam
	mov	ecx, 'XBO'

gsw2:	lodsb
	cmp	al, ':'
	jne	gsw0
	mov	dx, di		; jesli ':', to ...
gsw3:	lodsb			; ... pobierz nazwe
	stosb
	cmp	al, ' '
	je	gsw4
	cmp	al, '/'
	je	gsw4
	cmp	al, 0dh
	jne	gsw3
gsw4:	mov	[byte di-1], 0
	lda	ecx		; doczep ecx
	call	adext
	jmp	gsw0
gswx:	mov	al, [byte swits]
	and	al, m_lstl
	xor	al, m_lstl+m_lsto
	mov	[flist], al

	testsw	m_swe
	jz	noswe

prpsp:	mov	ax, [16h]
	mov	ds, ax
	cmp	ax, [16h]
	jne	prpsp

	mov	ax, [2ch]
	test	ax, ax
	jz	enver
	dec	ax
	mov	[cs:envseg], ax
	mov	ds, ax
	mov	es, ax
	mov	si, 10h
	mov	di, si
	xor	al, al

renv1:	cmp	al, [si]
	jz	renvx
	cmp	[word si], 'RE'
	jne	renv2
	cmp	[byte si+2], 'R'
	jne	renv2
	cmp	[byte si+7], '='
	jne	renv2
	cmp	[dword si+3], 'ELIF'
	je	renv3
	cmp	[dword si+3], 'ENIL'
	je	renv3
renv2:	movsb
	cmp	al, [si-1]
	jnz	renv2
	jmp	renv1
renv3:	lodsb
	test	al, al
	jnz	renv3
	jmp	renv1

enver:	push	cs
	pop	ds
	print	envtxt
	dos	4c02h

renvx:	push	cs
	pop	ds
	mov	[envofs], di
	stosb
	push	ds
	pop	es

noswe:	btr	[swits], b_swn
	jnc	noswn

	mov	dx, offset objnam	; sprawdz czas modyfikacji object'a
	dos	3d00h
	jc	noswn			; pewnie nie istnieje
	sta	bx			; handle -> bx
	dos	5700h
	mov	[word objmod], cx	; zapisz czas
	mov	[word high objmod], dx	; zapisz date
	dos	3eh
	setsw	m_swn		; sprawdzimy czas modyfikacji source'a

noswn:	mov	bp, offset var

npass:	mov	[orgvec], offset t_org-2
	mov	di, [fslen]

opfile:	call	fopen
	btr	[swits], b_swn
	jnc	main
	sta	bx
	dos	5700h			; sprawdz czas modyfikacji
	push	dx
	push	cx
	pop	eax
	cmp	eax, [objmod]
	ja	main
	print	oldtxt
	dos	4c00h

main:	mov	bx, [iclen]
	mov	bx, [(icl bx).prev]
	test	[(icl bx).flags], m_eofl
	jnz	filend		; czy byl juz koniec pliku ?

	mov	di, offset line	; ... nie - omin ewentualny LF
	call	fread1
	jz	filend
	cmp	[line], 0ah
	je	skiplf
	inc	di
skiplf:
	mov	bx, [iclen]
	mov	bx, [(icl bx).prev]
	inc	[(icl bx).line]	; zwieksz nr linii w pliku
	inc	[lines]		; ilosc wszystkich linii
	testsw	m_swi
	jz	gline1		; czy /I
	and	[flist], not m_lsti	; ... tak
	cmp	bx, offset t_icl
	jbe	gline1		; czy includowany plik ?
	or	[flist], m_lsti	; ... tak, nie listuj

gline1:	cmp	di, offset line+256
	jnb	linlon
	call	fread1
	jz	eof
	mov	al, [di]
	cmp	al, 0dh		; pc cr
	je	short syntax
	cmp	al, 0ah		; unix lf
	je	syntax
	cmp	al, 9bh		; atari eol
	je	syntax
	inc	di
	jmp	gline1

eof:	mov	bx, [iclen]	; koniec pliku
	or	[(icl bx).flags], m_eofl

syntax:	mov	[byte di], 0dh
	mov	[eolpos], di
	mov	[lstidx], offset lstorg
	mov	[labvec], 0
	mov	si, offset line	; asembluj linie
	call	rlabel
	jb	nolabl
	cmp	[skflag], 0
	jnz	labelx
	jpass2	deflp2		; jest etykieta
	call	flab0		; definicja etykiety w pass 1
	jnc	ltwice
	mov	di, [laben]
	mov	[labvec], di
	mov	ax, [origin]
	stosw			; domyslnie equ *
	mov	al, m_lnus
	mov	ah, dl
	stosw
	mov	cx, dx
	sub	cl, 4
	lda	si
	mov	si, offset tlabel
	rep	movsb		; przepisz nazwe
	sta	si
	mov	[laben], di
	cmp	di, offset t_lab+l_lab-4
	jb	labelx
	error	e_tlab

ltwice:	error	e_twice

deflp2:	mov	bx, [pslab]	; definicja etykiety w pass 2
	mov	[labvec], bx
	add	[pslab], dx	; oznacz jako minieta
	test	[(lab bx).flags], m_lnus
	jz	labelx
	testsw	m_swu
	jz	labelx
	push	si
	push	offset w_ulab
	call	warln
	pop	si
labelx:	cmp	[byte si], 0dh
	je	lstreo
	call	spaces

nolabl:	lodsb
	cmp	al, ' '
	je	nolabl
	cmp	al, 9
	je	nolabl
	cmp	al, '*'
	je	lstrem
	cmp	al, ';'
	je	lstrem
	cmp	al, '|'
	je	lstrem
	cmp	al, 0dh
	je	lstrem
	cmp	al, ':'
	jne	s_one
	call	getuns
	jc	unknow
	sta	cx
	jcxz	lstrem
	call	spaces
	jmp	s_cmd

lstrem:	cmp	[byte high labvec], 0
	jz	lstre1
lstreo:	call	chorg
	call	phorg

lstre1:	call	lstlin
	jmp	main

skip1:	lodsd			; sprawdz komende
	dec	si
	and	eax, 0dfdfdfh
	mov	di, offset cndtxt
	mov	cx, 5
	repne	scasd
	jne	lstcnd
	call	[word di-4+cndvec-cndtxt]
	cmp	[skflag], 0
	jz	lstre1
lstcnd:	testsw	m_swc
	jnz	lstre1
	jmp	main

s_one:	dec	si
	mov	cx, 1
s_cmd:	cmp	[skflag], 0
	jnz	skip1
	mov	[times], cx
	resfl	m_times
	setfl	m_first
	cmp	cx, 1
	je	jone
	setfl	m_times
jone:	testfl	m_norg
	jnz	nlorg
	call	phorg
nlorg:	mov	[cmdvec], si

rdcmd1:	resfl	m_pair

rdcmd2:	mov	[scdvec], 0
rdcmd3:	lodsw			; wez trzy litery
 	and	ax, 0dfdfh
	xchg	al, ah
	shl	eax, 16
	mov	ah, 0dfh
	and	ah, [si]
	jopcod	lbnox		; jezeli nie cytujemy ...
	mov	[obufpt], offset obuf	; (oprozniamy bufor wyjsciowy)
	testfl	m_norg
	jz	lbnox		; ... i nie bylo ORG ...
	cmp	[byte high labvec], 0
	je	lbnox		; ... a jest etykieta ...
	cmp	eax, 'EQU' shl 8
	call	nenorg		; ... to dozwolony jest tylko EQU
lbnox:	inc	si
	cmp	[byte si], ':'	; czy para instrukcji?
	jne	nopair
	jopcod	ntopco
	inc	si
	mov	[scdvec], si
	call	get		; w kolejnych trzech literach nie moze byc EOLa
	call	get
	call	get
	setfl	m_pair
nopair:	mov	di, offset comtab		; przeszukiwanie polowkowe
	mov	bx, 64*size com
sfcmd1:	mov	al, [(com di+bx).c_code]
	mov	[cod], al
	mov	al, [(com di+bx).c_flag]
	cmp	eax, [dword (com di+bx).c_flag]
	jb	sfcmd2
	je	fncmd
	add	di, bx
	cmp	di, offset comend
	jb	sfcmd2
	sub	di, bx
sfcmd2:	shr	bx, 1
	cmp	bl, 3
	ja	sfcmd1
	mov	bl, 0
	je	sfcmd1
	error	e_inst

ntrep:	error	e_crep

ntopco:	error	e_opcod

ntpair:	error	e_pair

ntrepa:	error	e_repa

fncmd:	test	al, 80h
	jz	ckcmd1
	jopcod	ntopco		; nie ma opcoda
ckcmd1:	test	al, 40h
	jz	ckcmd2
	testfl	m_times		; nie mozna powtarzac ...
	jnz	ntrep
	testfl	m_pair		; ... ani parowac
	jnz	ntpair
ckcmd2:	test	al, 20h		; dyrektywa?
	jz	ckcmd3
	test	al, 10h		; nie mozna generowac skoku przez dyrektywe
	jz	rncmd3		; (dyrektywa neutralna)
	resfl	m_repa		; skok zabroniony
	testfl	m_skit
	jz	rncmd3
eskit:	error	e_skit
ckcmd3:	jopcod	ckcmd4
	testfl	m_skit
	jz	ckcmd4
	inc	[origin]	; robimy miejsce na argument skoku
	inc	[curorg]
	inc	[obufpt]
	mov	cx, m_pair+m_times
	mov	dx, offset w_skif
	call	skirew
ckcmd4:	test	al, 08h
	jz	ckcmd5
	testfl	m_repa		; pseudo instrukcja powtarzania
	jz	ntrepa
	mov	cx, m_repl
	mov	dx, offset w_repl
	call	skirew
	jmp	rncmd2

ckcmd5:	setfl	m_repa
	test	al, 04h
	mov	ax, [origin]
	mov	[reporg], ax
	jz	rncmd2
	setfl	m_skit		; pseudo instrukcja omijania
	mov	[obuf], 2
	mov	al, [(com di+bx).c_code]
	call	savbyt
	jmp	encmd2

rncmd2:	resfl	m_repl
	testfl	m_pair+m_times
	jz	rncmd3
	setfl	m_repl		; ustaw repl, jesli koniec linii z para lub licznikiem
rncmd3:	mov	al, [cod]
	call	[(com di+bx).c_vec]	; wywolaj procedure
	btr	[flags], b_skit
	jnc	encmd2
	mov	ax, [origin]
	sub	ax, [reporg]
	add	ax, 80h
	call	calcbr
	mov	[obuf], al
encmd2:	call	oflush
	resfl	m_first
	mov	cx, [scdvec]
	jcxz	encmd3
	mov	si, cx
	jmp	rdcmd2
encmd3:	call	linend
	dec	[times]
	jz	main
	mov	si, [cmdvec]
	jmp	rdcmd1

skirew:	jpass1	skiret
	testfl	cx
	jz	skiret
	testfl	m_first
	jz	skiret
	pusha
	push	dx
	call	warln
	popa
skiret:	ret

; ERROR
errln:	call	ppline
erron:	call	prname
	print	errtxt
	pop	si
	call	msgenv
	dos	4c02h

; WARNING
warln:	call	ppline
	call	prname
	print	wartxt
	pop	ax
	pop	si
	push	ax
	mov	[byte exitcod], 1
msgenv:	call	prline
	btr	[flags], b_enve
	jnc	msgenx
	print	envtxt
msgenx:	ret

prname:	mov	bx, [iclen]
	cmp	bx, offset t_icl
	jna	msgenx
	mov	di, [(icl bx).prev]
	push	di
	lea	dx, [(icl di).nam]
	mov	[byte bx-1], '$'
	mov	[envnam], dx
	sub	bx, dx
	mov	[envlen], bx
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
	testsw	m_swe
	jz	msgenx
	les	di, [dword envofs]
	mov	ax, [es:3]
	shl	ax, 4
	sub	ax, di
	sub	ax, offset dectxt+10+19-1
	sub	ax, [envlen]
	add	ax, [envnum]
	mov	[envlen], ax
	js	senve
	mov	eax, 'FRRE'
	stosd
	mov	eax, '=ELI'
	stosd
	mov	si, [envnam]
senv1:	movsb
	cmp	[byte si], '$'
	jne	senv1
	xor	al, al
	stosb
	mov	eax, 'LRRE'
	stosd
	mov	eax, '=ENI'
	stosd
	mov	si, [envnum]
senv2:	movsb
	cmp	[byte si], '$'
	jne	senv2
	xor	ax, ax
	stosw
	push	ds
	pop	es
	ret

senve:	setfl	m_enve
	ret

ppline:	mov	si, offset line
prline:	mov	dl, [si]
	dos	2
	inc	si
	cmp	[byte si-1], 0dh
	jne	prline
	mov	dl, 0ah
	dos	2
	ret

miseif:	push	offset e_meif
	jmp	erron

skiten:	push	offset e_skit
	jmp	erron

; End of file
pofend:	pop	ax
filend:	call	fclose
	cmp	bx, offset t_icl
	ja	main
	jpass2	fin

	cmp	[elflag], 1
	jne	miseif
	testfl	m_skit
	jnz	skiten
	setfl	m_pass+m_norg+m_rorg+m_rqff+m_hdr+m_wobj
	and	[flist], not m_lsto
	jmp	npass

fin:	mov	bx, [ohand]
	mov	[errmsg], offset e_wrobj
	call	hclose
	testsw	m_swt
	jz	nlata			; czy /T ?
	cmp	[laben], offset t_lab	; ... tak
	jbe	nlata			; czy tablica pusta ?
	cmp	[byte tabnam], 0	; ... nie
	jnz	oplata		; czy dana nazwa ?
	cmp	[lhand], nhand	; ... nie
	jne	latt1		; czy otwarty listing ?
	call	opnlst		; ... nie - otworz
	jmp	latt2
latt1:	call	plseol
	jmp	latt2
oplata:	call	lclose		; zamknij listing
	mov	dx, offset tabnam
	call	opntab		; otworz tablica
latt2:	mov	dx, offset tabtxt
	mov	cx, tabtxl
	call	putlad
	mov	si, offset t_lab
lata1:	mov	di, offset lstnum
	mov	eax, '    '
	test	[(lab si).flags], m_lnus
	jz	lata2
	mov	al, 'n'
lata2:	test	[(lab si).flags], m_ukp1
	jz	lata3
	mov	ah, '2'
lata3:	stosd
	mov	ax, [(lab si).l_val]
	test	[(lab si).flags], m_sign
	jz	lata4
	mov	[byte di-1], '-'
	neg	ax
lata4:	call	phword
	mov	al, ' '
	stosb
	mov	cx, (offset (lab)-offset (lab).nam) and 0ffh
	add	cl, [(lab si).len]
	add	si, offset (lab).nam
	rep	movsb
	call	putlst
	cmp	si, [laben]
	jb	lata1

nlata:	call	lclose
	mov	eax, [lines]
	shr	eax, 1
	call	pridec
	print	lintxt
	mov	eax, [bytes]
	test	eax, eax
	jz	zrbyt
	call	pridec
	print	byttxt
zrbyt:	mov	ax, [exitcod]
;	dos	;!!!

; I/O
xdisk:	dos
	jnc	cloret
	push	[errmsg]
	jmp	erron

icler:	push	offset e_icl
	jmp	erron

lclose:	mov	bx, nhand	; mov	bx, [lhand]
	xchg	bx, [lhand]	; mov	[lhand], nhand
	mov	[errmsg], offset e_wrlst
hclose:	cmp	bx, nhand
	je	cloret
	jfile	3eh

fopen:	cmp	di, offset t_icl+l_icl-2
	jnb	icler
	mov	bx, [iclen]
	mov	[(icl bx).line], 0
	mov	[(icl bx).flags], 0
	lea	dx, [(icl bx).nam]
	mov	[(icl di).prev], bx
	mov	[iclen], di
	file	3d00h, e_open
	mov	bx, [iclen]
	mov	bx, [(icl bx).prev]
	mov	[(icl bx).handle], ax
cloret:	ret

fread1:	mov	dx, di
	mov	cx, 1
fread:	mov	ah, 3fh
fsrce:	mov	bx, [iclen]
	mov	bx, [(icl bx).prev]
	mov	bx, [(icl bx).handle]
	mov	[errmsg], offset e_read
	call	xdisk
	test	ax, ax
	ret

fclose:	mov	ah, 3eh
	call	fsrce
	mov	bx, [iclen]
	cmp	bx, [srcen]
	jne	fclos1
	mov	[srcen], 0
fclos1:	mov	bx, [(icl bx).prev]
	mov	[iclen], bx
	ret

putwor:	mov	cx, 2		; zapisz slowo do pliku
	mov	dx, offset oword
	mov	[oword], ax
putblk:	jpass1	putx		; zapisz blok
	cmp	[ohand], nhand
	jne	putb1		; otwarty object ?
	push	cx dx
	mov	dx, offset objnam	; ... nie - otworz
	xor	cx, cx
	file	3ch, e_crobj
	mov	[ohand], ax
	print	objtxt
	pop	dx cx
putb1:	mov	bx, [ohand]
	file	40h, e_wrobj
	movzx	ecx, cx
	add	[bytes], ecx
putx:	ret

orgwor:	push	ax
	call	phword
	pop	ax
	jmp	putwor

chorg:	testfl	m_norg
nenorg:	jz	putx
	error	e_norg

tmorgs:	error	e_orgs

incorg:	inc	[origin]
	ret

savwor:	push	ax
	call	savbyt
	pop	ax
	mov	al, ah

savbyt:	jopcod	xopco
	testfl	m_wobj
	jz	incorg
	mov	di, [obufpt]
	stosb
	mov	[obufpt], di
	testfl	m_hdr
	jz	savb1
	call	chorg
	mov	ax, [origin]
	testfl	m_rorg
	jnz	borg1
	cmp	ax, [curorg]
	je	borg3
borg1:	add	[orgvec], 2
	cmp	[orgvec], offset t_org+l_org
	jae	tmorgs
	jpass1	borg2
	mov	di, offset lstorg
	testfl	m_rqff
	jz	noff
	mov	ax, 0ffffh
	call	orgwor
	mov	ax, ' >'
	stosw
	mov	ax, [origin]
noff:	call	orgwor
	mov	al, '-'
	stosb
	mov	bx, [orgvec]
	mov	ax, [bx]
	call	orgwor
	mov	ax, ' >'
	stosw
	mov	ax, [origin]
	mov	[lstidx], di
borg2:	resfl	m_rorg+m_rqff
borg3:	jpass2	borg4
	mov	di, [orgvec]
	stosw
borg4:	inc	ax
	mov	[curorg], ax

savb1:	inc	[origin]
	cmp	[obufpt], offset obufen
	jb	oflur
	testfl	m_skit
	jnz	eskit

oflush:	mov	dx, offset obuf
	mov	cx, [obufpt]
	sub	cx, dx
	jz	oflur
	mov	[obufpt], dx
	call	putblk
	test	[flist], m_lsts
	jnz	oflur
	mov	bx, offset obuf
	mov	di, [lstidx]
olst1:	cmp	di, offset line-3
	jae	lstxtr
	mov	al, [bx]
	inc	bx
	call	phbyte
	mov	al, ' '
	stosb
	loop	olst1
olstx:	mov	[lstidx], di
oflur:	ret
lstxtr:	cmp	di, offset line-1
	jae	olstx
	mov	ax, ' +'
	stosw
	mov	[lstidx], di
linret:	ret

; Stwierdza blad, jesli nie spacja, tab lub eol
linend:	lodsb
	cmp	al, 0dh
	je	linen1
	cmp	al, ' '
	je	linen1
	cmp	al, 9
	je	linen1
	error	e_xtra
; Listuje linie po ostatnim przebiegu
linen1:	cmp	[times], 1
	jne	linret
; Listuje linie
lstlin:	test	[flist], m_lsts
	jnz	linret
	mov	di, offset lstspa
	mov	bx, [iclen]
	mov	bx, [(icl bx).prev]
	mov	eax, [(icl bx).line]
	call	numdec
	mov	al, ' '
lstl1:	dec	di
	mov	[di], al
	cmp	di, offset lstnum
	ja	lstl1
	mov	di, [lstidx]
	mov	cx, offset line
	sub	cx, di
	rep	stosb
	mov	[lstspa], al

	mov	bx, [iclen]
	cmp	bx, [srcen]
	je	nlsrc		; czy zmienil sie asemblowany plik ?
	mov	[srcen], bx	; ... tak
	cmp	[lhand], nhand
	jne	lsrc1		; otwarty listing ?
	call	opnlst		; ... nie - otworz
lsrc1:	mov	dx, offset srctxt
	mov	cx, offset srctxl
	call	putlad		; komunikat o nowym source'u
	mov	bx, [iclen]
	mov	cx, bx
	mov	bx, [(icl bx).prev]
	lea	dx, [(icl bx).nam]
	stc
	sbb	cx, dx
	call	putlad		; nazwa
	call	plseol
nlsrc:
	mov	di, [eolpos]
	testsw	m_sws
	jnz	ctrail		; jezeli nie ma /S ...
	mov	si, offset lstnum
	mov	di, si		; ... zamien spacje na taby
spata1:	xor	dl, dl
spata2:	lodsb
	cmp	al, 0dh
	je	ctrail
	stosb
	cmp	al, 9
	je	spata1
	dec	dx
	cmp	al, ' '
	jne	spata2
	and	dx, 7
	jz	spata2
	mov	cx, dx
	mov	bx, si
spata3:	cmp	al, [bx]
	jne	spata2
	inc	bx
	loop	spata3
	mov	[byte di-1], 9
	mov	si, bx
	jmp	spata1

strail:	dec	di
ctrail:	cmp	[byte di-1], ' '
	je	strail
	cmp	[byte di-1], 9
	je	strail
putlst:	mov	ax, 0a0dh
	stosw
	lea	cx, [di+zero-lstnum]
	mov	dx, offset lstnum
putlad:	mov	bx, [lhand]
	jfile	40h, e_wrlst

opnlst:	mov	dx, offset lstnam
opntab:	xor	cx, cx
	file	3ch, e_crlst
	mov	[lhand], ax
	print	lsttxt
	mov	dx, offset hello
	mov	cx, hellen
	jmp	putlad

plseol:	mov	dx, offset eoltxt
	mov	cx, 2
	jmp	putlad

adasx:	mov	eax, 'XSA'
; Dodaj rozszerzenie nazwy, gdy go nie ma
; we: dx,di-poczatek,koniec nazwy; eax-rozszerzenie
adext:	mov	bx, di
adex1:	dec	bx
	cmp	[byte bx], '\'
	je	adex2
	cmp	[byte bx], '.'
	je	adexr
	cmp	bx, dx
	ja	adex1
adex2:	mov	[byte di-1], '.'
	stosd
adexr:	ret

; Zapisz dziesietnie eax; di-koniec liczby
numdec:	mov	ebx, 10
numde1:	cdq
	div	ebx
	add	dl, '0'
	dec	di
	mov	[di], dl
	test	eax, eax
	jnz	numde1
	ret

; Wyswietl dziesietnie eax
pridec:	mov	di, offset dectxt+10
	call	numdec
	mov	dx, di
	mov	[envnum], di
	print
	ret

; Zapisz hex origin
phorg:	mov	di, offset lstorg
	mov	ax, [origin]
	call	phword		; listuj * hex
	mov	al, ' '
	stosb
	mov	[lstidx], di
	ret

; Zapisz hex ax od [di]
phword:	push	ax
	mov	al, ah
	call	phbyte
	pop	ax
phbyte:	aam	10h
	cmp	al, 10
	sbb	al, 69h
	das
	xchg	al, ah
	cmp	al, 10
	sbb	al, 69h
	das
	stosw
	ret

; Pobierz znak (eol=error)
get:	lodsb
	cmp	al, 0dh
	je	uneol
	ret
uneol:	error	e_uneol

; Omin spacje i tabulatory
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

; Pobierz nazwe pliku
rfname:	call	spaces
	mov	di, offset (icl).nam
	add	di, [iclen]
; Pobierz lancuch do [di]
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

; Przepisz etykiete do tlabel (wyj: dx-dl.etykiety+4)
rlabel:	mov	di, offset tlabel
	mov	[byte di], 0
rlab1:	lodsb
	cmp	al, '0'
	jb	rlabx
	cmp	al, '9'
	jbe	rlab2
	cmp	al, '_'
	je	rlab2
	and	al, 0dfh
	cmp	al, 'A'
	jb	rlabx
	cmp	al, 'Z'
	ja	rlabx
rlab2:	stosb
	cmp	di, offset tlabel+252
	jb	rlab1
linlon:	push	offset e_long
	jmp	erron
rlabx:	lea	dx, [di+zero-tlabel+lab.nam]
	dec	si
	cmp	[byte tlabel], 'A'
	ret

; Czytaj etykiete i szukaj w t_lab
; wyj: dx-dlugosc etykiety+4
; C=0: znaleziona, bx=adres wpisu
; C=1: nie ma jej
flabel:	call	rlabel
	jb	ilchar
flab0:	push	si
	xor	cx, cx
	mov	si, offset t_lab
	mov	ax, [laben]
	dec	ax
flab1:	add	si, cx
	cmp	ax, si
	jb	flabx
	mov	cl, [(lab si).len]
	cmp	cl, dl
	jne	flab1
	add	si, offset (lab).nam
	sub	cl, offset (lab).nam
	mov	di, offset tlabel
	repe	cmpsb
	jne	flab1
	lea	bx, [si+tlabel-offset (lab).nam]
	sub	bx, di	; c=0
flabx:	pop	si
	ret

wropar:	error	e_wpar

spaval:	call	spaces
; Czytaj wyrazenie i zwroc jego wartosc w [val]
; (C=1 wartosc nieokreslona w pass 1)
getval:	xor	bx, bx
	mov	[ukp1], bh
	push	bx

v_lop:
v_par1:	inc	bh
v_par0:	call	get
	cmp	al, '['
	je	v_par1
	mov	di, offset opert0
	mov	cx, noper0
	repne	scasb
	jne	v_n1a
	sub	di, offset opert0-noper1-noper2
	call	goprpa
	push	di bx
	jmp	v_par0

v_n1a:	cmp	al, '('
	je	wropar
	movzx	eax, al
	cmp	al, '*'
	je	valorg
	cmp	al, "'"
	je	valchr
	cmp	al, '"'
	je	valchr
	cmp	al, '^'
	je	valreg
	cmp	al, '{'
	je	valquo
	mov	di, -1
	cdq		; xor edx, edx
	mov	ecx, 16
	cmp	al, '$'
	je	rdnum3
	mov	cl, 2
	cmp	al, '%'
	je	rdnum3
	mov	cl, 10
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
	movzx	edi, al
	lda	edx
	mul	ecx
	add	eax, edi
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
vlabfn:	and	[(lab bx).flags], not m_lnus
	jpass1	vlchuk
	cmp	bx, [pslab]
	jb	vlchuk
	test	[(lab bx).flags], m_ukp1
	jz	vlukp1
	error	e_fref
vlchuk:	test	[(lab bx).flags], m_ukp1
	jz	vlabkn
vlukp1:	mov	[ukp1], 0ffh
vlabkn:	bt	[word (lab bx).flags], b_sign
	sbb	eax, eax
	mov	ax, [(lab bx).l_val]
	pop	bx
	jmp	value1

valorg:	call	chorg
	mov	ax, [origin]
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
	sub	al, '0'
	cmp	al, 4
	ja	ilchar
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
	jmp	value1

valquo:	jopcod	rcopco
	push	bx
	mov	[opcosp], sp
	mov	bp, offset var2
	jmp	rdcmd3
xopco:	mov	sp, [opcosp]
	mov	bp, offset var
	mov	ah, al
	call	get
	cmp	al, '}'
	jne	msopco
	movzx	eax, ah
	pop	bx
	jmp	value1

rcopco:	error	e_ropco

msopco:	error	e_mopco

value0:	dec	si
	test	di, di
	js	ilchar
	lda	edx
value1:	push	eax
v_par2:	dec	bh
	js	mbrack
	lodsb
	cmp	al, ']'
	je	v_par2

	mov	ah, [si]
	mov	di, offset opert2
	mov	cx, noper2
	repne	scasw
	je	foper2		; operator 2-znakowy
	mov	cx, noper1
	repne	scasb
	je	foper1		; operator 1-znakowy
	test	bh, bh		; koniec wyrazenia
	jnz	mbrack		; musza byc zamkniete nawiasy
	dec	si
	mov	di, offset opert1
foper1:	sub	di, offset opert1
	jmp	goper
foper2:	inc	si
	sub	di, offset opert2
	shr	di, 1
	add	di, noper1
goper:	call	goprpa
	pop	eax
v_com:	pop	cx
	cmp	cx, bx
	jb	v_xcm
	pop	dx
	cmp	dx, offset v_1arg
	jae	v_r1a
	sta	ecx
	pop	eax
v_r1a:	push	offset v_com
	push	dx
	ret
v_xcm:	cmp	bl, 1
	jbe	v_xit
	push	cx eax di bx
	jmp	v_lop
v_xit:	mov	[dword val], eax
	cmp	[ukp1], 1
	cmc
	jc	unsret
wrange:	cmp	eax, 10000h
	cmc
	jnb	unsret
	cmp	eax, -0ffffh
	jb	orange
	ret

brange:	cmp	eax, 100h
	jb	unsret
	cmp	eax, -0ffh
	jb	orange
	ret

spauns:	call	spaces
getuns:	call	getval
	pushf
	jnc	getun1
	jpass1	getun2
getun1:	test	eax, eax
	js	orange
getun2:	popf
unsret:	ret

getpos:	call	getval
	jc	unknow
	test	eax, eax
	jg	unsret

orange:	error	e_range

mbrack:	error	e_brack

toobig:	error	e_nbig

; Procedury operatorow nie moga zmieniac bx ani di

v_sub:	neg	ecx		; -
v_add:	add	eax, ecx	; +
	jno	v_ret
oflow:	error	e_over

div0:	error	e_div0

v_mul:	mov	edx, ecx	; *
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

v_div:	jecxz	div0		; /
	cdq
	idiv	ecx
	ret

v_mod:	jecxz	div0		; %
	cdq
	idiv	ecx
	sta	edx
	ret

v_sln:	neg	ecx
v_sal:	test	ecx, ecx	; <<
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
p_skp:
v_ret:	ret

v_srn:	neg	ecx
v_sar:	test	ecx, ecx	; >>
	js	v_sln
	cmp	ecx, 20h
	jb	v_sr1
	mov	cl, 1fh
v_sr1:	sar	eax, cl
	ret

v_and:	and	eax, ecx	; &
	ret

v_or:	or	eax, ecx	; |
	ret

v_xor:	xor	eax, ecx	; ^
	ret

v_equ:	cmp	eax, ecx	; =
v_eq1:	je	v_one
v_zer:	xor	eax, eax
	ret
v_one:	mov	eax, 1
	ret

v_neq:	cmp	eax, ecx	; <> !=
	jne	v_one
	jmp	v_zer

v_les:	cmp	eax, ecx	; <
	jl	v_one
	jmp	v_zer

v_grt:	cmp	eax, ecx	; >
	jg	v_one
	jmp	v_zer

v_leq:	cmp	eax, ecx	; <=
	jle	v_one
	jmp	v_zer

v_geq:	cmp	eax, ecx	; >=
	jge	v_one
	jmp	v_zer

v_anl:	jecxz	v_zer		; &&
	test	eax, eax
	jz	v_ret
	jmp	v_one

v_orl:	or	eax, ecx	; ||
	jz	v_ret
	jmp	v_one

; Operatory 1-argumentowe
v_1arg:
v_neg:	neg	eax
v_plu:	ret

v_low:	movzx	eax, al
	ret

v_hig:	movzx	eax, ah
	ret

v_nol:	test	eax, eax
	jmp	v_eq1

v_not:	not	eax
	ret

goprpa:	lea	ax, [di+operpa]
	add	di, di
	add	di, ax
	mov	bl, [di]
	mov	di, [di+1]
	ret

onemod:	jnopcod	getadr
	cmp	[byte si], '}'
	jne	getadr
	jmp	xopco

getaim:	jnopcod	getai0
	cmp	[byte si], '}'
	je	getai2
getai0:	cmp	al, '<'
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

; Pobierz operand rozkazu i rozpoznaj tryb adresowania
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
	je	getao1
	dec	si
	lodsw
	and	al, 0dfh
	mov	dl, 2
	cmp	ax, ':A'
	je	getao2
	inc	dx
	cmp	ax, ':Z'
	je	getao2
	dec	si
	dec	si
	xor	dx, dx

getad1:	push	dx
	call	getuns
	sbb	al, al
	jnz	getad2
	mov	al, [byte high val]
getad2:	pop	dx
getad9:	cmp	dl, 8
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

getao1:	jnopcod	getad1
	cmp	[byte si], ')'
	je	getaid
getao2:	jnopcod	getad1
	cmp	[byte si], ','
	je	getad9
	cmp	[byte si], '}'
	je	getad9
	jmp	getad1
	
getaid:	lodsb
	cmp	al, ','
	je	getaix
	call	chkpar
	lodsw
	mov	dx, 1009h
	mov	bl, 14h
	cmp	ax, '0,'
	je	getaxt
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
	mov	dh, 8
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
acc1:	cmp	ah, 8
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
	cmp	al, 89h	; sta #
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
	and	al, 7
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
	mov	al, 0ch
	je	putcod
	mov	al, 4
	jmp	putcod

p_rep:
	mov	ax, [origin]
	xchg	ax, [reporg]
	jmp	bra0

p_bra:	call	onemod
	and	al, 0feh
	cmp	al, 2
	jne	ilamod
	mov	ax, [val]
bra0:	jpass1	bra1
	call	chorg
	sub	ax, [origin]
	add	ax, 7eh
	call	calcbr
	mov	[byte val], al
bra1:	mov	al, [cod]
	call	savbyt
	mov	al, [byte val]
	jmp	savbyt

calcbr:	test	ah, ah
	jnz	toofar
	add	al, 80h
	ret

toofar:	cmp	ax, 8080h
	jae	toofa1
	sub	ax, 0ffh
	neg	ax
toofa1:	neg	ax
	mov	di, offset brout
	call	phword
	error	e_bra

p_jsr:	call	onemod
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
	testfl	m_norg		; nieznany * (przy OPT H-)
	jnz	p_jpu
	mov	ax, [val]	; moze branch wystarczy?
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
	lea	di, [op1]
	call	stop
	push	[word ukp1]
	call	getadr
	pop	[word ukp1]
	mov	[tempsi], si
	lea	di, [op2]
	call	stop
	movzx	bx, [cod]
	add	bx, offset movtab
ldop1:	lea	si, [op1]
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

mcall1:	mov	al, [(movt bx).m_code]
	mov	[cod], al
	push	bx
	call	[(movt bx).m_vec]
	pop	bx
	ret

mcall2:	mov	al, [(movt bx+3).m_code]
	mov	[cod], al
	push	bx
	call	[(movt bx+3).m_vec]
	pop	bx
	ret

p_mvs:	call	getops
	call	mcall1
	lea	si, [op2]
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
	lea	si, [op2]
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
p_mw3:	lea	si, [op2]
	call	ldop
	inc	[val]
	jmp	p_mvx

p_opt:	call	spaces
	xor	dx, dx
	jmp	opt0
opt1:	shr	cx, 1
	bts	dx, cx
	jc	opter
	call	[word di-2+optvec-opttxt]
opt0:	lodsw
	and	al, 0dfh
	mov	cx, 6
	mov	di, offset opttxt
	repne	scasw
	je	opt1
	test	dx, dx
	jz	opter
	dec	si
	dec	si
	ret

opter:	error	e_opt

optl0:	or	[flist], m_lsto
	ret
optl1:	jpass1	optr
	and	[flist], not m_lsto
optr:	ret
opth0:	resfl	m_hdr+m_rqff
	ret
opth1:	bts	[flags], b_hdr
	jc	optr
	setfl	m_rorg
	ret
opto0:	resfl	m_wobj
	ret
opto1:	setfl	m_wobj
	ret

p_ert:	call	spaval
	jpass1	equret
	test	eax, eax
	jz	equret
	error	e_user

p_equ:	mov	di, [labvec]
	test	di, di
	jz	nolabd
	mov	[(lab di).l_val], 0
	and	[(lab di).flags], not m_sign
	call	spaval
	mov	di, [labvec]
	jnc	equ1
	or	[(lab di).flags], m_ukp1
equ1:	mov	[(lab di).l_val], ax
	test	eax, eax
	jns	equ2
	or	[(lab di).flags], m_sign
equ2:	test	[flist], m_lsts
	jnz	equret
	sta	dx
	mov	di, offset lstorg
	mov	ax, ' ='
	test	eax, eax
	jns	equ3
	mov	ah, '-'
	neg	dx
equ3:	stosw
	lda	dx
	call	phword
	mov	[lstidx], di
equret:	ret

nolabd:	error	e_label

chkhon:	testfl	m_hdr
	jnz	equret
	error	e_hoff

p_org:	call	spaces
	lodsw
	and	al, 0dfh
	cmp	ax, ':F'
	je	orgff
	cmp	ax, ':A'
	je	orgaf
	dec	si
	dec	si
	jmp	orget
orgff:	setfl	m_rqff
orgaf:	setfl	m_rorg
	call	chkhon
orget:	call	getuns
	jc	unknow
setorg:	resfl	m_norg
	mov	[origin], ax
	ret

p_rui:	call	chkhon
	mov	ah, 2
	call	setorg
	call	spauns
	jmp	savwor

valuco:	call	getval
	jc	unknow
	call	get
	cmp	al, ','
	jne	badsin
	mov	ax, [val]
	ret
badsin:	error	e_sin

dtan0:	cmp	al, 'A'
	je	dtan1
	cmp	al, 'B'
	je	dtan1
	cmp	al, 'L'
	je	dtan1
	cmp	al, 'H'
	je	dtan1
	cmp	al, 'R'
	jne	dtab1
	jmp	dtar1

dtat0:	cmp	al, 'C'
	je	dtat1j
	cmp	al, 'D'
	jne	dtab1
dtat1j:	dec	si
	mov	[cod], al
	jmp	dtat1

p_dta:	call	spaces
dta1:	lodsw
	and	al, 0dfh
	cmp	ah, '('
	je	dtan0
	cmp	ah, "'"
	je	dtat0
	cmp	ah, '"'
	je	dtat0
dtab1:	dec	si
	dec	si
	mov	al, ' '
dtan1:	mov	[cod], al

dtan2:	lodsd
	and	eax, 0ffdfdfdfh
	cmp	eax, '(NIS'
	jne	dtansi
	call	valuco
	mov	[sinadd], eax
	call	valuco
	mov	[sinamp], eax
	call	getpos
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
	cmp	ax, [sinmin]
	jb	badsin
	mov	[sinmax], ax
	lodsb
	call	chkpar
presin:	finit
	fldpi
	fld	st
	faddp	st(1), st
	fidiv	[sinsiz]
gensin:	fild	[sinmin]
	fmul	st, st(1)
	fsin
	fimul	[sinamp]
	fiadd	[sinadd]
	fistp	[dword val]
	inc	[sinmin]
	mov	eax, [dword val]
	call	wrange
	jmp	dtasto
	
dtansi:	sub	si, 4
	call	getval
dtasto:	mov	al, [cod]
	cmp	al, 'A'
	je	dtana
	jpass1	dtans
	cmp	al, 'L'
	je	dtanl
	cmp	al, 'H'
	je	dtanh
	mov	eax, [dword val]
	call	brange
	jmp	dtans

dtana:	mov	ax, [val]
	call	savwor
	jmp	dtanx

dtanl:	mov	al, [byte low val]
	jmp	dtans

dtanh:	mov	al, [byte high val]

dtans:	call	savbyt
dtanx:	mov	ax, [sinmin]
	cmp	ax, [sinmax]
	jbe	gensin
	cmp	[cod], ' '
	je	dtanxt
	lodsb
	cmp	al, ','
	je	dtan2
dtanp:	push	offset dtanxt
chkpar:	cmp	al, ')'
	je	paret
	error	e_paren

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
ascinx:	push	ax cx
	call	savbyt
	pop	cx ax
	loop	dtatm
	pop	si
dtanxt:	lodsb
	cmp	al, ','
	je	dta1
	dec	si
paret:	ret

; Zapisz liczbe rzeczywista
dtar1:
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
ilchar:	error	e_char
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
	jmp	dreale
dreal5:	test	edx, edx
	jnz	dreal9
	test	bl, bl
	jnz	dreal9
	dec	cx
dreal9:	call	putdig
drealp:	call	getdig
	jnc	dreal5
dreale:	and	al, 0dfh
	cmp	al, 'E'
	jne	drealf
	call	getsgn
	call	getdig
	jc	ilchar
	mov	ah, al
	call	getdig
	jnc	dreal4
	shr	ax, 8
	dec	si
dreal4:	inc	si
	aad
	add	di, di
	jnc	drealn
	neg	ax
drealn:	add	cx, ax
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
	rol	edx, 16
dreals:	push	edx
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
	jmp	dtanp

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
	je	sgnret	; C=0
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
	push	di
	call	linend
	mov	dx, offset (icl).nam
	add	dx, [iclen]
	pop	di
	call	adasx
	jmp	opfile

p_ins:	call	rfname
	xor	eax, eax
	mov	[insofs], eax
	mov	[inslen], ax
	lodsb
	cmp	al, ','
	jne	p_ii2
	push	di
	call	getval
	jc	unknow
	mov	[insofs], eax
	lodsb
	cmp	al, ','
	jne	p_ii1
	call	getpos
	mov	[inslen], ax
	inc	si
p_ii1:	pop	di
p_ii2:	dec	si
	push	si
	call	fopen
	mov	dx, [word insofs]
	mov	cx, [word high insofs]
	mov	ax, 4200h
	jcxz	p_ip1
	mov	al, 2
p_ip1:	call	fsrce
p_in1:	mov	cx, [inslen]
	jcxz	p_in2
	test	ch, ch
	jz	p_in3
p_in2:	mov	cx, 256
p_in3:	mov	dx, offset tlabel
	call	fread
	jz	p_inx
	cwde
	mov	bx, [iclen]
	mov	bx, [(icl bx).prev]
	add	[(icl bx).line], eax
	mov	si, offset tlabel
	push	ax
	sta	cx
p_inp:	lodsb
	push	cx
	call	savbyt
	pop	cx
	loop	p_inp
	pop	ax
	cmp	[inslen], 0
	jz	p_in1
	sub	[inslen], ax
	jnz	p_in1
p_inx:	call	fclose
	pop	si
	cmp	[inslen], 0
	jz	rlret
	error	e_fshor

p_end:	pop	ax
	call	linend
	jmp	filend

p_ift:	shl	[elflag], 1
	jc	etmift
	shl	[cmflag], 1
	shl	[skflag], 1
ift1:	call	spaval
	jc	unknow
	test	eax, eax
	jnz	ift2
ift0:	setflag	[skflag], 1
	ret

p_els:	bts	[elflag], 0
	jc	cnderr
ift2:	bts	[cmflag], 0
	jc	ift0
	maskflag [skflag], not 1
cndret:	ret

p_eli:	testflag [elflag], 1
	jz	ift1
cnderr:	cmp	[elflag], 1
	je	emift
	error	e_eifex

p_eif:	shr	[skflag], 1
	shr	[cmflag], 1
	shr	[elflag], 1
	jnz	cndret
emift:	error	e_mift

etmift:	error	e_tmift

; addressing modes:
; 0-@ 1-# 2-A 3-Z 4-A,X 5-Z,X 6-A,Y 7-Z,Y 8-(Z,X) 9-(Z),Y 10-(A)
lentab	db	1,2,3,2,3,2,3,2,2,2,3
acctab	db	0,9,0dh,5,1dh,15h,19h,19h,1,11h,0
srttab	db	0ah,0,0eh,6,1eh,16h
lditab	db	0,0,0ch,4,1ch,14h,1ch,14h
inwtab	db	0eeh,0e6h,0feh,0f6h
; pseudo-adr modes: 2-X+ 3-X- 4-Y+ 5-Y-
; +8-,0) +16-),0
sfxtab	db	0,0,0e8h,0cah,0c8h,088h

movtab	movt	<0a0h,p_ac1>,<080h,p_ac1>
	movt	<0a2h,p_ld1>,<086h,p_st1>
	movt	<0a0h,p_ld1>,<084h,p_st1>

comtab:	cmd	ADC0060p_acc
	cmd	ADD8018p_ads
	cmd	AND0020p_acc
	cmd	ASL0000p_srt
	cmd	BCC0090p_bra
	cmd	BCS00b0p_bra
	cmd	BEQ00f0p_bra
	cmd	BIT002cp_bit
	cmd	BMI0030p_bra
	cmd	BNE00d0p_bra
	cmd	BPL0010p_bra
	cmd	BRK0000p_imp
	cmd	BVC0050p_bra
	cmd	BVS0070p_bra
	cmd	CLC0018p_imp
	cmd	CLD00d8p_imp
	cmd	CLI0058p_imp
	cmd	CLV00b8p_imp
	cmd	CMP00c0p_acc
	cmd	CPX00e0p_cpi
	cmd	CPY00c0p_cpi
	cmd	DEC00c0p_srt
	cmd	DEX00cap_imp
	cmd	DEY0088p_imp
	cmd	DTA8000p_dta
	cmd	EIFe000p_eif
	cmd	ELIe000p_eli
	cmd	ELSe000p_els
	cmd	ENDe000p_end
	cmd	EOR0040p_acc
	cmd	EQUe000p_equ
	cmd	ERTe000p_ert
	cmd	ICLe000p_icl
	cmd	IFTe000p_ift
	cmd	INC00e0p_srt
	cmd	INIf0e2p_rui
	cmd	INSf000p_ins
	cmd	INW8000p_inw
	cmd	INX00e8p_imp
	cmd	INY00c8p_imp
	cmd	JCC80b0p_juc
	cmd	JCS8090p_juc
	cmd	JEQ80d0p_juc
	cmd	JMI8010p_juc
	cmd	JMP004cp_jmp
	cmd	JNE80f0p_juc
	cmd	JPL8030p_juc
	cmd	JSR0020p_jsr
	cmd	JVC8070p_juc
	cmd	JVS8050p_juc
	cmd	LDA00a0p_acc
	cmd	LDX00a2p_ldi
	cmd	LDY00a0p_ldi
	cmd	LSR0040p_srt
	cmd	MVA8000p_mvs
	cmd	MVX8006p_mvs
	cmd	MVY800cp_mvs
	cmd	MWA8000p_mws
	cmd	MWX8006p_mws
	cmd	MWY800cp_mws
	cmd	NOP00eap_imp
	cmd	OPTe000p_opt
	cmd	ORA0000p_acc
	cmd	ORGf000p_org
	cmd	PHA0048p_imp
	cmd	PHP0008p_imp
	cmd	PLA0068p_imp
	cmd	PLP0028p_imp
	cmd	RCC8890p_rep
	cmd	RCS88b0p_rep
	cmd	REQ88f0p_rep
	cmd	RMI8830p_rep
	cmd	RNE88d0p_rep
	cmd	ROL0020p_srt
	cmd	ROR0060p_srt
	cmd	RPL8810p_rep
	cmd	RTI0040p_imp
	cmd	RTS0060p_imp
	cmd	RUNf0e0p_rui
	cmd	RVC8850p_rep
	cmd	RVS8870p_rep
	cmd	SBC00e0p_acc
	cmd	SCC8490p_skp
	cmd	SCS84b0p_skp
	cmd	SEC0038p_imp
	cmd	SED00f8p_imp
	cmd	SEI0078p_imp
	cmd	SEQ84f0p_skp
	cmd	SMI8430p_skp
	cmd	SNE84d0p_skp
	cmd	SPL8410p_skp
	cmd	STA0080p_acc
	cmd	STX0086p_sti
	cmd	STY0084p_sti
	cmd	SUB8038p_ads
	cmd	SVC8450p_skp
	cmd	SVS8470p_skp
	cmd	TAX00aap_imp
	cmd	TAY00a8p_imp
	cmd	TSX00bap_imp
	cmd	TXA008ap_imp
	cmd	TXS009ap_imp
	cmd	TYA0098p_imp
comend:

operpa:	opr	1ret
	opr	6add
	opr	6sub
	opr	7mul
	opr	7div
	opr	7mod
	opr	7and
	opr	6or
	opr	6xor
	opr	5equ
	opr	5les
	opr	5grt
	opr	7sal
	opr	7sar
	opr	5leq
	opr	5geq
	opr	5neq
	opr	5neq
	opr	5equ
	opr	3anl
	opr	2orl
	opr	8plu
	opr	8neg
	opr	8low
	opr	8hig
	opr	4nol
	opr	8not

opert2	db	'<<>><=>=<>!===&&||'
noper2	=	($-opert2)/2
opert1	db	'+-*/%&|^=<>'
noper1	=	$-opert1
opert0	db	'+-<>!~'
noper0	=	$-opert0

opttxt	db	'L-L+H-H+O-O+'
optvec	dw	optl0,optl1,opth0,opth1,opto0,opto1

cndtxt	dd	'DNE','TFI','ILE','SLE','FIE'
cndvec	dw	pofend,0,p_ift,0,p_eli,0,p_els,0,p_eif

swilet	db	'UTSONLIEC'

hello	db	'X-Assembler 2.4.-7'
	ifdef	SET_WIN_TITLE
titfin	db	0
	else
	db	' '
	endif
	db	'by Fox/Taquart',eot
hellen	=	$-hello-1
usgtxt	db	"Syntax: XASM source [options]",eol
	db	"/c         List false conditionals",eol
	db	"/e         Set environment variables on error",eol
	db	"/i         Don't list included source",eol
	db	"/l[:fname] Generate listing",eol
	db	"/n         Assemble only if source newer than object",eol
	db	"/o:fname   Write object as 'fname'",eol
	db	"/s         Don't convert spaces to tabs in listing",eol
	db	"/t[:fname] List label table",eol
	db	"/u         Warn of unused labels",eot
oldtxt	db	'Source is older than object - not assembling',eot
envtxt	db	'Can''t change environment',eot
objtxt	db	'Writing object...',eot
lsttxt	db	'Writing listing...'
eoltxt	db	eot
srctxt	db	'Source: '
srctxl	=	$-srctxt
tabtxt	db	'Label table:',eol
tabtxl	=	$-tabtxt
lintxt	db	' lines of source assembled',eot
byttxt	db	' bytes written to object',eot
dectxt	db	10 dup(' '),'$'
wartxt	db	'WARNING: $'
w_bugjp	db	'Buggy indirect jump',eol
w_bras	db	'Branch would be sufficient',eol
w_ulab	db	'Unused label',eol
w_skif	db	'Skipping only first instruction',eol
w_repl	db	'Repeating only last instruction',eol
errtxt	db	'ERROR: $'
e_open	db	'Can''t open file',cr
e_read	db	'Disk read error',cr
e_crobj	db	'Can''t write object',cr
e_wrobj	db	'Error writing object',cr
e_crlst	db	'Can''t write listing',cr
e_wrlst	db	'Error writing listing',cr
e_icl	db	'Too many files nested',cr
e_long	db	'Line too long',cr
e_uneol	db	'Unexpected eol',cr
e_char	db	'Illegal character',cr
e_twice	db	'Label declared twice',cr
e_inst	db	'Illegal instruction',cr
e_nbig	db	'Number too big',cr
e_xtra	db	'Extra characters on line',cr
e_label	db	'Label name required',cr
e_str	db	'String error',cr
e_orgs	db	'Too many ORGs',cr
e_paren	db	'Need parenthesis',cr
e_tlab	db	'Too many labels',cr
e_amod	db	'Illegal addressing mode',cr
e_bra	db	'Branch out of range by $'
brout	db	'     bytes',cr
e_sin	db	'Bad or missing sinus parameter',cr
e_spac	db	'Space expected',cr
e_opt	db	'Invalid options',cr
e_over	db	'Arithmetic overflow',cr
e_div0	db	'Divide by zero',cr
e_range	db	'Value out of range',cr
e_uknow	db	'Label not defined before',cr
e_undec	db	'Undeclared label',cr
e_fref	db	'Illegal forward reference',cr
e_wpar	db	'Use square brackets instead',cr
e_brack	db	'No matching bracket',cr
e_user	db	'User error',cr
e_tmift	db	'Too many IFTs nested',cr
e_eifex	db	'EIF expected',cr
e_mift	db	'Missing IFT',cr
e_meif	db	'Missing EIF',cr
e_norg	db	'No ORG specified',cr
e_fshor	db	'File is too short',cr
e_hoff	db	'Illegal when headers off',cr
e_crep	db	'Can''t repeat this directive',cr
e_opcod	db	'Can''t get op-code of this',cr
e_ropco	db	'Nested op-codes not supported',cr
e_mopco	db	'Missing ''}''',cr
e_pair	db	'Can''t pair this directive',cr
e_skit	db	'Can''t skip over it',cr
e_repa	db	'No instruction to repeat',cr

exitcod	dw	4c00h
ohand	dw	nhand
lhand	dw	nhand
flags	dw	m_norg+m_rorg+m_rqff+m_hdr+m_wobj
swits	dw	0
lines	dd	0
bytes	dd	0
srcen	dw	0
iclen	dw	t_icl
laben	dw	t_lab
pslab	dw	t_lab
elflag	dd	1
cmflag	dd	0
skflag	dd	0
sinmin	dw	1
sinmax	dw	0
sinadd	dd	?
sinamp	dd	?
sinsiz	dw	?
flist	db	?
fslen	dw	?
times	dw	?
cmdvec	dw	?
scdvec	dw	?
opcosp	dw	?
insofs	dd	?
inslen	dw	?
origin	dw	?
curorg	dw	?
orgvec	dw	?
reporg	dw	?
eolpos	dw	?
lstidx	dw	?
labvec	dw	?
obufpt	dw	?
oword	dw	?
objmod	dd	?
op1	dd	?
	dw	?
op2	dd	?
	dw	?
tempsi	dw	?
errmsg	dw	?
envofs	dw	?
envseg	dw	?
envnam	dw	?
envnum	dw	?
envlen	dw	?

var:
MACRO	bb	_name
_name&o	=	$-var
_name	equ	byte bp+_name&o
	db	?
	ENDM

MACRO	bw	_name
_name&o	=	$-var
_name	equ	word bp+_name&o
	dw	?
	ENDM

	bw	val
	dw	?
	bb	amod
	db	?
	bb	ukp1
	db	?
	bb	cod

var2	db	($-var) dup(?)

IFNDEF	compak
	undata
ENDIF

t_lab	db	l_lab dup(?)

	ENDS
	END	start