%global debug_package %{nil}

Name:           vylo-pip
Version:        0.4.0
Release:        1%{?dist}
Summary:        PIP, the optional VYLO desktop helper
License:        MIT
URL:            https://github.com/spaceayyat/MyOS
Source0:        vylo-%{version}.tar.gz

BuildRequires:  cmake gcc-c++ make
BuildRequires:  qt6-qtbase-devel qt6-qtdeclarative-devel layer-shell-qt-devel
Requires:       layer-shell-qt
Requires:       libnotify
Requires:       xdg-utils
Requires:       grim

%description
A small helper for the VYLO desktop. It opens applications and links, downloads
files after asking, sets reminders and changes desktop settings. It is switched
off until you turn it on, and removing this package removes it completely.

%prep
%autosetup -n vylo-%{version}

%build
%cmake -DVYLO_BUILD_DESKTOP=OFF -DVYLO_BUILD_PIP=ON
%cmake_build

%install
%cmake_install

%files
%license LICENSE
%{_bindir}/vylo-pip
%{_datadir}/applications/vylo-pip.desktop
%{_datadir}/icons/hicolor/scalable/apps/vylo-pip.svg
