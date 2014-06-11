xasm
====

xasm is a 6502 cross-assembler with original syntax extensions.
By default it generates binaries
for [Atari 8-bit computers](http://en.wikipedia.org/wiki/Atari_8-bit_family).

Syntax
------

6502 assembly language is full of LDA, STA, LDA, STA sequences.
With xasm you can use MVA as a shortcut for an LDA/STA pair or even MWA for 16-bit transfers.
You can avoid defining labels when you need short jumps,
thanks to conditional skip and repeat pseudo-instructions.
You can put two instructions that share their argument in one line.
These are just some of the features that help you program in a more concise way.
Let's look at typical 6502 code (which is also valid in xasm):

        lda #<dest
        sta ptr
        lda #>dest
        sta ptr+1
        ldx #192
    do_line
        ldy #39
    do_byte
        lda pattern,y
        sta (ptr),y
        dey
        bpl do_byte
        lda #40
        clc
        adc ptr
        sta ptr
        bcc skip
        inc ptr+1
    skip
        dex
        bne do_line

Using xasm's features this code can be rewritten to:

        mwa     #dest ptr
        ldx     #192
    do_line
        ldy     #39
        mva:rpl pattern,y (ptr),y-
        lda #40
        add:sta ptr
        scc:inc ptr+1
        dex:bne do_line

xasm syntax is based on 1990's Quick Assembler.
Write accumulator shifts as in `asl @`.
Whitespace is important: it is required before the instruction
and disallowed in the operands, because it separates a comment from the operand, e.g.

        lda #0   this is a comment, no need for a semicolon

This may look weird at first, but it enables nice features such as instruction pairs
and two-argument pseudo-instructions.

Usage
-----

xasm is a command-line tool.
Therefore you additionally need a programmer's text editor.

I use [SciTE](http://www.scintilla.org/SciTE.html).
To install xasm syntax highlighting, copy `xasm.properties`
to the SciTE directory.

I build my 8-bit programs with GNU Make,
having configured SciTE to run "make" on Ctrl+1.
See [my repositories](https://github.com/pfusik?tab=repositories) on GitHub.

Download
--------

A release is coming soon.
Meanwhile you can download Windows binaries from the [old website](http://xasm.atari.org/).

Links
-----

* [Atari800](http://atari800.sourceforge.net/) - portable emulator of Atari 8-bit computers
* [Atari XL/XE Source Archive](http://sources.pigwa.net/) - source code of Atari demos, utilities and games
* [cc65](http://cc65.github.io/cc65/) - C cross-compiler targeting 6502-based systems
* [MADS](http://mads.atari8.info/) - another 6502/65816 cross-assembler, partially supporting xasm's syntax
* [WUDSN IDE](http://wudsn.com/) - Eclipse plugin, front-end to several 6502 cross-assemblers including xasm
