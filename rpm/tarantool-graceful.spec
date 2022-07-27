Name: tarantool-graceful
Version: 1.0.0
Release: 1%{?dist}
Summary: Graceful initialization/finalization/code reload for tarantool modules
Group: Applications/Databases
License: BSD2
URL: https://github.com/maksimuimin/graceful
Source0: graceful-%{version}.tar.gz
BuildArch: noarch
BuildRequires: tarantool-devel >= 1.6.8.0
Requires: tarantool >= 1.6.8.0
Requires: tarantool-checks >= 3.1.0

%description
Graceful initialization/finalization/code reload for tarantool modules

%prep
%setup -q -n graceful-%{version}

%check
./test/graceful.test.lua

%install
# Create /usr/share/tarantool/graceful
mkdir -p %{buildroot}%{_datadir}/tarantool/graceful
# Copy init.lua to /usr/share/tarantool/graceful/init.lua
cp -p graceful/*.lua %{buildroot}%{_datadir}/tarantool/graceful

%files
%dir %{_datadir}/tarantool/graceful
%{_datadir}/tarantool/graceful/
%doc README.md
%{!?_licensedir:%global license %doc}
%license LICENSE AUTHORS

%changelog
* Wed Aug 27 2022 Maksim Uimin <uimin1maksim@yandex.ru> 1.0.0-1
- Initial version of the RPM spec
