Name: xasm
Version: 3.1.1
Release: 1
Summary: 6502 cross-assembler
License: Poetic
Group: Applications/Programming
Source: http://pfusik.github.io/xasm/xasm-%{version}.tar.gz
URL: https://github.com/pfusik/xasm
BuildRequires: dmd >= 2, asciidoc
BuildRoot: %{_tmppath}/%{name}-root

%description
xasm is a 6502 cross-assembler with original syntax extensions.

%global debug_package %{nil}

%prep
%setup -q

%build
make xasm xasm.1

%install
rm -rf $RPM_BUILD_ROOT
make DESTDIR=$RPM_BUILD_ROOT prefix=%{_prefix} install

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%{_bindir}/xasm
%{_mandir}/man1/xasm.1.gz

%changelog
* Wed Nov 20 2019 Piotr Fusik <fox@scene.pl>
- 3.1.1-1

* Sun Jul 20 2014 Piotr Fusik <fox@scene.pl>
- 3.1.0-1
- Initial packaging
