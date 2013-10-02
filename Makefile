VERSION = 3.1.0

all: xasm.exe xasm.html

xasm.exe: xasm.d
	dmd -O -release $<

xasm.html: xasm.1.txt
	asciidoc -o - -d manpage $< | sed -e "s/527bbd;/20a0a0;/" >$@

xasm-$(VERSION)-windows.zip: xasm.exe xasm.html xasm.properties
	rm -f $@ && 7z a -mx=9 -tzip $@ $^

clean:
	$(RM) xasm-$(VERSION)-windows.zip xasm.exe xasm.html

.PHONY: all clean

.DELETE_ON_ERROR:
