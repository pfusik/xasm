VERSION = 3.1.0

prefix = /usr/local
bindir = $(prefix)/bin
mandir = $(prefix)/share/man/man1

all: xasm xasm.html

xasm: xasm.d
	dmd -O -release $<

xasm.html: xasm.1.txt
	asciidoc -o - $< | sed -e "s/527bbd;/20a0a0;/" >$@

xasm.1: xasm.1.txt
	a2x -f manpage $<

xasm-$(VERSION)-windows.zip: xasm xasm.html xasm.properties
	$(RM) $@ && 7z a -mx=9 -tzip $@ xasm.exe xasm.html xasm.properties

install: xasm xasm.1
	mkdir -p $(DESTDIR)$(bindir) && install xasm $(DESTDIR)$(bindir)/xasm
	mkdir -p $(DESTDIR)$(mandir) && install -m 644 xasm.1 $(DESTDIR)$(mandir)/xasm.1

uninstall:
	$(RM) $(DESTDIR)$(bindir)/xasm $(DESTDIR)$(mandir)/xasm.1

deb:
	debuild -b -us -uc

osx: xasm-$(VERSION)-osx.dmg

xasm-$(VERSION)-osx.dmg: osx/xasm osx/bin
	hdiutil create -volname xasm-$(VERSION)-osx -srcfolder osx -imagekey zlib-level=9 -ov $@

osx/xasm: xasm
	mkdir -p osx && cp $< $@

osx/bin:
	mkdir -p osx && ln -s /usr/bin $@

clean:
	$(RM) xasm xasm.exe xasm.obj xasm.html xasm.1 xasm-$(VERSION)-windows.zip xasm-$(VERSION)-osx.dmg
	rm -rf osx

.PHONY: all install uninstall deb osx clean

.DELETE_ON_ERROR:
