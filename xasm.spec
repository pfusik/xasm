%global ldc_version 1.43.0

Name: xasm
Version: 3.3.0
Release: 1
Summary: 6502 cross-assembler
License: Poetic
Source0: http://pfusik.github.io/xasm/xasm-%{version}.tar.gz
# Official LDC release: links druntime/Phobos statically,
# so the binary doesn't depend on the Fedora release's ldc-libs
Source1: https://github.com/ldc-developers/ldc/releases/download/v%{ldc_version}/ldc2-%{ldc_version}-linux-%{_arch}.tar.xz
URL: https://github.com/pfusik/xasm
ExclusiveArch: x86_64 aarch64
BuildRequires: gcc, make, asciidoctor

%description
xasm is a 6502 cross-assembler with original syntax extensions.

%global debug_package %{nil}

%prep
%setup -q -a 1

%build
make LDC2=$PWD/ldc2-%{ldc_version}-linux-%{_arch}/bin/ldc2 xasm xasm.1

%install
make DESTDIR=%{buildroot} prefix=%{_prefix} install

%files
%{_bindir}/xasm
%{_mandir}/man1/xasm.1.gz

%changelog
* Mon Nov 2 2026 Piotr Fusik <fox@scene.pl>
- 3.3.0-1

* Thu Dec 8 2022 Piotr Fusik <fox@scene.pl>
- 3.2.1-1

* Tue Jun 22 2021 Piotr Fusik <fox@scene.pl>
- 3.2.0-1

* Wed Nov 20 2019 Piotr Fusik <fox@scene.pl>
- 3.1.1-1

* Sun Jul 20 2014 Piotr Fusik <fox@scene.pl>
- 3.1.0-1
- Initial packaging
