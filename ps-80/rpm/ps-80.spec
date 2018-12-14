Name:           Percona-Server-80-info
Version:        8.0
Release:        1%{?dist}
Summary:        Information package for Percona-Server-80

Group:          Applications/Databases
License:        Copyright (c) 2000, 2018, Oracle and/or its affiliates. All rights reserved. Under GPLv2 license as shown in the Description field.
URL:            http://www.percona.com/
Packager:       Percona MySQL Development Team <mysqldev@percona.com>
Vendor:         Percona, Inc

%description
Information package for Percona-Server-80

%prep


%build


%install


%files


%post
echo "====================================================================="
echo -e "\033[1mPercona Server 8.0 has been moved to a separate repository\033[0m"
echo "To avoid conflicts with previous versions of Percona Server, the 8.0 release has been moved to a separate repository.   The percona-release package contains a tool which allows you to easily enable it."
echo ""
echo -e "\033[1msudo percona-release setup ps80\033[0m"
echo ""
echo "This command will disable the original repository and enable the Percona Server 8.0 repository. In addition, it will enable our new tools repository which contains Percona XtraBackup 8.0 and other tools that you may find useful."
echo "For more information about our percona-release tool, please visit:"
echo -e "\033[1mhttps://www.percona.com/doc/percona-repo-config/percona-release.html\033[0m"
echo "====================================================================="

%changelog
* Fri Dec 14 2018 Evgeniy Patlan <evgeniy.patlan@percona.com>
- Initial build
