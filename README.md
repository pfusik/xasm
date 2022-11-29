[![GitHub Actions](https://github.com/pfusik/xasm/actions/workflows/test.yml/badge.svg)](https://github.com/pfusik/xasm/actions/workflows/test.yml)

xasm
====

xasm is a 6502 cross-assembler with original syntax extensions.
By default it generates binaries
for [Atari 8-bit computers](http://en.wikipedia.org/wiki/Atari_8-bit_family).

Syntax
------

6502 assembly code is full of LDA, STA, LDA, STA sequences.
With xasm you can use MVA as a shortcut for an LDA/STA pair or even MWA for 16-bit transfers.
Short branches can be replaced with conditional skip and repeat pseudo-instructions.
You can use a pair of instructions with a shared argument.
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
        lda     #40
        add:sta ptr
        scc:inc ptr+1
        dex:bne do_line

xasm syntax is an extension of Quick Assembler's (created in 1991 for Atari 8-bit).
Accumulator shifts should be written as in `asl @`.
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
To install xasm syntax highlighting and single-keystroke compilation,
copy `xasm.properties` to the SciTE directory.

For single source file programs, press Ctrl+F7 to compile.
You can double-click error messages to go to the incorrect line.
Press F5 to run the program in the emulator.

For larger projects, I use GNU Make. Press F7 to build (and possibly run)
a project as described in the `Makefile`. You can find my Makefiles in
[my repositories](https://github.com/pfusik?tab=repositories) on GitHub.

If you prefer VIM, see a link below.

Poetic License
--------------

This work 'as-is' we provide.  
No warranty express or implied.  
We've done our best,  
to debug and test.  
Liability for damages denied.

Permission is granted hereby,  
to copy, share, and modify.  
Use as is fit,  
free or for profit.  
These rights, on this notice, rely.  

Download
--------

[xasm 3.2.0](https://github.com/pfusik/xasm/releases) for Windows, macOS, Ubuntu and Fedora.

Links
-----

* [Atari800](https://atari800.github.io/) - portable emulator of Atari 8-bit computers
* [Atari XL/XE Source Archive](http://sources.pigwa.net/) - source code of Atari demos, utilities and games
* [cc65](https://cc65.github.io/) - C cross-compiler targeting 6502-based systems
* [MADS](http://mads.atari8.info/) - another 6502/65816 cross-assembler, partially supporting xasm's syntax
* [vim-xasm](https://github.com/lybrown/vim-xasm) - VIM syntax highlighting for xasm
* [WUDSN IDE](http://wudsn.com/) - Eclipse plugin, front-end to several 6502 cross-assemblers, including xasm
