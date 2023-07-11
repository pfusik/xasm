Name: xasm
Version: 3.2.1
Release: 1
Summary: 6502 cross-assembler
License: Poetic
Source: http://pfusik.github.io/xasm/xasm-%{version}.tar.gz
URL: https://github.com/pfusik/xasm
BuildRequires: dmd >= 2, asciidoc

%description
xasm is a 6502 cross-assembler with original syntax extensions.

%global debug_package %{nil}

%prep
%setup -q

%build
make xasm xasm.1

%install
make DESTDIR=%{buildroot} prefix=%{_prefix} install

%files
%{_bindir}/xasm
%{_mandir}/man1/xasm.1.gz

%changelog
* Thu Dec 8 2022 Piotr Fusik <fox@scene.pl>
- 3.2.1-1

* Tue Jun 22 2021 Piotr Fusik <fox@scene.pl>
- 3.2.0-1

* Wed Nov 20 2019 Piotr Fusik <fox@scene.pl>
- 3.1.1-1

* Sun Jul 20 2014 Piotr Fusik <fox@scene.pl>
- 3.1.0-1
- Initial packaging
