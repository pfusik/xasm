VERSION = 3.2.0

prefix = /usr/local
bindir = $(prefix)/bin
mandir = $(prefix)/share/man/man1
ifeq ($(OS),Windows_NT)
EXEEXT = .exe
endif

SEVENZIP = 7z a -mx=9 -bd -bso0

all: xasm$(EXEEXT) xasm.html

xasm$(EXEEXT): source/app.d
	dmd -of$@ -O -release $<

xasm.html: xasm.1.asciidoc
	asciidoc -o - $< | sed -e "s/527bbd;/20a0a0;/" >$@

xasm.1: xasm.1.asciidoc
	a2x -f manpage $<

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

../xasm-$(VERSION)-windows.zip: xasm xasm.html xasm.properties signed
	$(RM) $@ && $(SEVENZIP) -tzip $@ xasm.exe xasm.html xasm.properties

signed: xasm$(EXEEXT)
	signtool sign -d "xasm $(VERSION)" -n "Open Source Developer, Piotr Fusik" -tr http://time.certum.pl -fd sha256 -td sha256 $< && touch $@

deb:
	debuild -b -us -uc

osx: ../xasm-$(VERSION)-macos.dmg

../xasm-$(VERSION)-macos.dmg: osx/xasm osx/bin
ifdef PORK_CODESIGNING_IDENTITY
	codesign --options runtime -f -s $(PORK_CODESIGNING_IDENTITY) osx/xasm
endif
	hdiutil create -volname xasm-$(VERSION)-macos -srcfolder osx -format UDBZ -fs HFS+ -imagekey bzip2-level=3 -ov $@
ifdef PORK_NOTARIZING_CREDENTIALS
	xcrun altool --notarize-app --primary-bundle-id com.github.pfusik.xasm $(PORK_NOTARIZING_CREDENTIALS) --file $@ \
		| perl -pe 's/^RequestUUID =/xcrun altool $$ENV{PORK_NOTARIZING_CREDENTIALS} --notarization-info/ or next; $$c = $$_; until (/Status: success/) { sleep 20; $$_ = `$$c`; print; } last;'
endif

osx/xasm: source/app.d
	mkdir -p osx && dmd -of$@ -O -release $< && rm -f osx/xasm.o

osx/bin:
	mkdir -p osx && ln -s /usr/local/bin $@

clean:
	$(RM) xasm xasm.exe xasm.obj xasm.html xasm.1 signed
	rm -rf osx

.PHONY: all install uninstall install-scite uninstall-scite dist srcdist MANIFEST deb osx clean

.DELETE_ON_ERROR:
