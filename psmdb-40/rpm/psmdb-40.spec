Name:           Percona-Server-MongoDB-40-info
Version:        4.0
Release:        1%{?dist}
Summary:        Information package for Percona-Server-MongoDB-40

Group:          Applications/Databases
License:        AGPL 3.0
URL:            https://github.com/percona/percona-server-mongodb.git

%description
Information package for Percona-Server-MongoDB-40

%prep


%build


%install


%files


%post
echo "====================================================================="
echo -e "\033[1mPercona Server for MongoDB 4.0 has been moved to a separate repository\033[0m"
echo "To avoid conflicts with previous versions of Percona Server for MongoDB, the 4.0 release has been moved to a separate repository.   The percona-release package contains a tool which allows you to easily enable it."
echo ""
echo -e "\033[1msudo percona-release setup psmdb40\033[0m"
echo ""
echo "This command will disable the original repository and enable the Percona Server for MongoDB 4.0 repository. In addition, it will enable our new tools repository which contains Percona XtraBackup 8.0 and other tools that you may find useful."
echo "For more information about our percona-release tool, please visit:"
echo -e "\033[1mhttps://www.percona.com/doc/percona-repo-config/percona-release.html\033[0m"
echo "====================================================================="

%changelog
* Fri Dec 14 2018 Evgeniy Patlan <evgeniy.patlan@percona.com>
- Initial build
