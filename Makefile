VERSION = 3.1.0

all: xasm xasm.html

xasm: xasm.d
	dmd -O -release $<

xasm.html: xasm.1.txt
	asciidoc -o - $< | sed -e "s/527bbd;/20a0a0;/" >$@

xasm.1: xasm.1.txt
	a2x -f manpage $<

xasm-$(VERSION)-windows.zip: xasm xasm.html xasm.properties
	$(RM) $@ && 7z a -mx=9 -tzip $@ xasm.exe xasm.html xasm.properties

clean:
	$(RM) xasm-$(VERSION)-windows.zip xasm xasm.exe xasm.html xasm.1

.PHONY: all clean

.DELETE_ON_ERROR:
