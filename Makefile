VERSION = 3.3.0

prefix = /usr/local
bindir = $(prefix)/bin
mandir = $(prefix)/share/man/man1
ifeq ($(OS),Windows_NT)
EXEEXT = .exe
endif

SEVENZIP = 'C:/Program Files/7-Zip/7z' a -mx=9 -bd -bso0

SOURCES = source/app.d source/xasm/package.d

all: xasm$(EXEEXT) xasm.html libxasm.html

xasm$(EXEEXT): $(SOURCES)
	ldc2 -of=$@ -O -release $^

xasm.html: xasm.1.asciidoc
	asciidoctor -o - $< | sed -e "s/ba3925;/20a0a0;/" >$@

libxasm.html: source/xasm/package.d
	ldc2 -D --Df=$@ -o- $^

xasm.1: xasm.1.asciidoc
	asciidoctor -b manpage $<

install: xasm xasm.1
	mkdir -p $(DESTDIR)$(bindir) && install xasm $(DESTDIR)$(bindir)/xasm
	mkdir -p $(DESTDIR)$(mandir) && install -m 644 xasm.1 $(DESTDIR)$(mandir)/xasm.1

uninstall:
	$(RM) $(DESTDIR)$(bindir)/xasm $(DESTDIR)$(mandir)/xasm.1

install-scite: xasm.properties
	mkdir -p $(DESTDIR)$(prefix)/share/scite && install -m 644 $< $(DESTDIR)$(prefix)/share/scite/xasm.properties

uninstall-scite:
	$(RM) $(DESTDIR)$(prefix)/share/scite/xasm.properties

dist: srcdist ../xasm-$(VERSION)-windows.zip

srcdist: MANIFEST
	$(RM) ../xasm-$(VERSION).tar.gz && /usr/bin/tar -c --numeric-owner --owner=0 --group=0 --mode=644 -T MANIFEST --transform=s,,xasm-$(VERSION)/, | $(SEVENZIP) -tgzip -si ../xasm-$(VERSION).tar.gz

MANIFEST:
	if test -e .git; then (git ls-files | grep -vF .gitignore && echo MANIFEST) | sort | dos2unix >$@ ; fi

../xasm-$(VERSION)-windows.zip: xasm.exe xasm.html xasm.properties signed
	$(RM) $@ && $(SEVENZIP) -tzip $@ xasm.exe xasm.html xasm.properties

signed: xasm$(EXEEXT)
	signtool sign -d "xasm $(VERSION)" -n "Open Source Developer Piotr Fusik" -tr http://time.certum.pl -fd sha256 -td sha256 $< && touch $@

deb:
	debuild -b -us -uc

osx: ../xasm-$(VERSION)-macos.dmg

../xasm-$(VERSION)-macos.dmg: osx/xasm osx/bin
ifdef FOX_CODESIGNING_IDENTITY
	codesign --options runtime -f -s $(FOX_CODESIGNING_IDENTITY) osx/xasm
endif
	hdiutil create -volname xasm-$(VERSION)-macos -srcfolder osx -format UDBZ -fs HFS+ -imagekey bzip2-level=3 -ov $@
	/Applications/Xcode.app/Contents/Developer/usr/bin/notarytool submit --wait --keychain-profile foxnotary $@

osx/xasm: $(SOURCES)
	mkdir -p osx && ldc2 -of=$@ -O -release $^ && rm -f osx/xasm.o

osx/bin:
	mkdir -p osx && ln -s /usr/local/bin $@

clean:
	$(RM) xasm xasm.exe xasm.obj xasm.html libxasm.html xasm.1 signed
	rm -rf osx

.PHONY: all install uninstall install-scite uninstall-scite dist srcdist MANIFEST deb osx clean

.DELETE_ON_ERROR:
