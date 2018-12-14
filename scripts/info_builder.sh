#!/bin/sh

shell_quote_string() {
  echo "$1" | sed -e 's,\([^a-zA-Z0-9/_.=-]\),\\\1,g'
}

usage () {
    cat <<EOF
Usage: $0 [OPTIONS]
    The following options may be given :
        --builddir=DIR      Absolute path to the dir where all actions will be performed
        --get_sources       Source will be downloaded from github
        --build_src_rpm     If it is set - src rpm will be built
        --build_src_deb     If it is set - source deb package will be built
        --build_rpm         If it is set - rpm will be built
        --build_deb         If it is set - deb will be built
        --build_tarball     If it is set - tarball will be built
        --install_deps      Install build dependencies(root privilages are required)
        --branch            Branch for build
        --product           Specify product for which package should be built(ps-80,psmdb-40,pxc-80)
        --repo              Repo for build
        
        --help) usage ;;
Example $0 --builddir=/tmp/info_package --get_sources=1 --build_src_rpm=1 --build_rpm=1
EOF
        exit 1
}

append_arg_to_args () {
  args="$args "$(shell_quote_string "$1")
}

parse_arguments() {
    pick_args=
    if test "$1" = PICK-ARGS-FROM-ARGV
    then
        pick_args=1
        shift
    fi
  
    for arg do
        val=$(echo "$arg" | sed -e 's;^--[^=]*=;;')
        case "$arg" in
            --builddir=*) WORKDIR="$val" ;;
            --build_src_rpm=*) SRPM="$val" ;;
            --build_src_deb=*) SDEB="$val" ;;
            --build_rpm=*) RPM="$val" ;;
            --build_deb=*) DEB="$val" ;;
            --get_sources=*) SOURCE="$val" ;;
            --build_tarball=*) TARBALL="$val" ;;
            --branch=*) BRANCH="$val" ;;
            --repo=*) REPO="$val" ;;
            --product=*) PRODUCT="$val" ;;
            --install_deps=*) INSTALL="$val" ;;
            --help) usage ;;      
            *)
              if test -n "$pick_args"
              then
                  append_arg_to_args "$arg"
              fi
              ;;
        esac
    done
}

check_workdir(){
    if [ "x$WORKDIR" = "x$CURDIR" ]
    then
        echo >&2 "Current directory cannot be used for building!"
        exit 1
    else
        if ! test -d "$WORKDIR"
        then
            echo >&2 "$WORKDIR is not a directory."
            exit 1
        fi
    fi
    return
}

get_sources(){
    cd "${WORKDIR}"
    if [ "${SOURCE}" = 0 ]
    then
        echo "Sources will not be downloaded"
        return 0
    fi
    echo "PRODUCT=${PRODUCT}" >> ${WORKDIR}/info_package.properties
    echo "BUILD_NUMBER=${BUILD_NUMBER}" >> ${WORKDIR}/info_package.properties
    echo "BUILD_ID=${BUILD_ID}" >> ${WORKDIR}/info_package.properties
    git clone "$REPO"
    retval=$?
    if [ $retval != 0 ]
    then
        echo "There were some issues during repo cloning from github. Please retry one more time"
        exit 1
    fi
    cd info_packages
    if [ ! -z "$BRANCH" ]
    then
        git reset --hard
        git clean -xdf
        git checkout "$BRANCH"
    fi
    mv ${PRODUCT} ${DIR_NAME}
    tar --owner=0 --group=0 --exclude=.* -czf ${DIR_NAME}.tar.gz ${DIR_NAME}
    echo "UPLOAD=UPLOAD/experimental/BUILDS/${PRODUCT}/${PRODUCT}/${DIR_NAME}/${BUILD_ID}" >> ${WORKDIR}/info_package.properties
    echo "DIR_NAME=${DIR_NAME}" >> ${WORKDIR}/info_packages.properties
    mkdir $WORKDIR/source_tarball
    mkdir $CURDIR/source_tarball
    cp ${DIR_NAME}.tar.gz $WORKDIR/source_tarball
    cp ${DIR_NAME}.tar.gz $CURDIR/source_tarball
    cd $CURDIR
    return
}

get_system(){
    if [ -f /etc/redhat-release ]; then
        RHEL=$(rpm --eval %rhel)
        ARCH=$(echo $(uname -m) | sed -e 's:i686:i386:g')
        OS_NAME="el$RHEL"
        OS="rpm"
    else
        ARCH=$(uname -m)
        OS_NAME="$(lsb_release -sc)"
        OS="deb"
    fi
    return
}

install_deps() {
    if [ $INSTALL = 0 ]
    then
        echo "Dependencies will not be installed"
        return;
    fi
    if [ ! $( id -u ) -eq 0 ]
    then
        echo "It is not possible to instal dependencies. Please run as root"
        exit 1
    fi
    CURPLACE=$(pwd)

    if [ "x$OS" = "xrpm" ]; then
      yum -y install wget
      yum clean all
      RHEL=$(rpm --eval %rhel)
      yum -y install rpmbuild rpm-build rpmlint rpmdevtools git
    else
      export DEBIAN=$(lsb_release -sc)
      export ARCH=$(echo $(uname -m) | sed -e 's:i686:i386:g')
      INSTALL_LIST="devscripts debhelper debconf pkg-config git "
      until apt-get update; do
        sleep 1
        echo "waiting"
      done
      until apt-get -y install ${INSTALL_LIST}; do
        sleep 1
        echo "waiting"
      done
    fi
    return;
}

get_tar(){
    TARBALL=$1
    TARFILE=$(basename $(find $WORKDIR/$TARBALL -name "${DIR_NAME}.tar.gz" | sort | tail -n1))
    if [ -z $TARFILE ]
    then
        TARFILE=$(basename $(find $CURDIR/$TARBALL -name "${DIR_NAME}.tar.gz" | sort | tail -n1))
        if [ -z $TARFILE ]
        then
            echo "There is no $TARBALL for build"
            exit 1
        else
            cp $CURDIR/$TARBALL/$TARFILE $WORKDIR/$TARFILE
        fi
    else
        cp $WORKDIR/$TARBALL/$TARFILE $WORKDIR/$TARFILE
    fi
    return
}

get_deb_sources(){
    param=$1
    echo $param
    FILE=$(basename $(find $WORKDIR/source_deb -name "${DIR_NAME}*.${param}" | sort | tail -n1))
    if [ -z $FILE ]
    then
        FILE=$(basename $(find $CURDIR/source_deb -name "${DIR_NAME}*.${param}" | sort | tail -n1))
        if [ -z $FILE ]
        then
            echo "There is no sources for build"
            exit 1
        else
            cp $CURDIR/source_deb/$FILE $WORKDIR/
        fi
    else
        cp $WORKDIR/source_deb/$FILE $WORKDIR/
    fi
    return
}

build_srpm(){
    if [ $SRPM = 0 ]
    then
        echo "SRC RPM will not be created"
        return;
    fi
    if [ "x$OS" = "xdeb" ]
    then
        echo "It is not possible to build src rpm here"
        exit 1
    fi
    cd $WORKDIR
    get_tar "source_tarball"
    rm -fr rpmbuild
    ls | grep -v tar.gz | xargs rm -rf
    TARFILE=$(find . -name "${DIR_NAME}.tar.gz" | sort | tail -n1)
    SRC_DIR=${TARFILE%.tar.gz}
    #
    mkdir -vp rpmbuild/{SOURCES,SPECS,BUILD,SRPMS,RPMS}
    tar vxzf ${WORKDIR}/${TARFILE}
    #
    cp ${WORKDIR}/${DIR_NAME}/rpm/*.spec ${WORKDIR}/rpmbuild/SPECS
    rpmbuild -bs --define "_topdir ${WORKDIR}/rpmbuild" --define "dist .generic" rpmbuild/SPECS/${PRODUCT}.spec
    mkdir -p ${WORKDIR}/srpm
    mkdir -p ${CURDIR}/srpm
    cp rpmbuild/SRPMS/*.src.rpm ${CURDIR}/srpm
    cp rpmbuild/SRPMS/*.src.rpm ${WORKDIR}/srpm
    return
}

build_rpm(){
    if [ $RPM = 0 ]
    then
        echo "RPM will not be created"
        return;
    fi
    if [ "x$OS" = "xdeb" ]
    then
        echo "It is not possible to build rpm here"
        exit 1
    fi
    SRC_RPM=$(basename $(find $WORKDIR/srpm -iname "${DIR_NAME}*.src.rpm" | sort | tail -n1))
    if [ -z $SRC_RPM ]
    then
        SRC_RPM=$(basename $(find $CURDIR/srpm -iname "${DIR_NAME}*.src.rpm" | sort | tail -n1))
        if [ -z $SRC_RPM ]
        then
            echo "There is no src rpm for build"
            echo "You can create it using key --build_src_rpm=1"
            exit 1
        else
            cp $CURDIR/srpm/$SRC_RPM $WORKDIR
        fi
    else
        cp $WORKDIR/srpm/$SRC_RPM $WORKDIR
    fi
    cd $WORKDIR
    rm -fr rpmbuild
    mkdir -vp rpmbuild/{SOURCES,SPECS,BUILD,SRPMS,RPMS}
    cp $SRC_RPM rpmbuild/SRPMS/
    
    RHEL=$(rpm --eval %rhel)
    ARCH=$(echo $(uname -m) | sed -e 's:i686:i386:g')
    echo "RHEL=${RHEL}" >> info_package.properties
    echo "ARCH=${ARCH}" >> info_package.properties
    rpmbuild --define "_topdir ${WORKDIR}/rpmbuild" --define "dist .$OS_NAME" --rebuild rpmbuild/SRPMS/$SRC_RPM

    return_code=$?
    if [ $return_code != 0 ]; then
        exit $return_code
    fi
    mkdir -p ${WORKDIR}/rpm
    mkdir -p ${CURDIR}/rpm
    cp rpmbuild/RPMS/*/*.rpm ${WORKDIR}/rpm
    cp rpmbuild/RPMS/*/*.rpm ${CURDIR}/rpm
}

build_source_deb(){
    if [ $SDEB = 0 ]
    then
        echo "source deb package will not be created"
        return;
    fi
    if [ "x$OS" = "xrmp" ]
    then
        echo "It is not possible to build source deb here"
        exit 1
    fi
    get_tar "source_tarball"
    rm -f *.dsc *.orig.tar.gz *.debian.tar.gz *.changes
    #
    TARFILE=$(basename $(find . -iname "${DIR_NAME}.tar.gz" | sort | tail -n1))
    DEBIAN=$(lsb_release -sc)
    ARCH=$(echo $(uname -m) | sed -e 's:i686:i386:g')
    tar zxf ${TARFILE} 
    BUILDDIR=${TARFILE%.tar.gz}
    VERSION=$(grep Version ${BUILDDIR}/debian/control | awk '{print $2}')
    RELEASE=$(grep Release ${BUILDDIR}/debian/control | awk '{print $2}')
    #
    mv ${TARFILE} ${DIR_NAME}_${VERSION}-1.orig.tar.gz
    cd ${BUILDDIR}
    dpkg-buildpackage -S
    cd ../
    mkdir -p $WORKDIR/source_deb
    mkdir -p $CURDIR/source_deb
    cp *_source.changes $WORKDIR/source_deb
    cp *.dsc $WORKDIR/source_deb
    cp *.orig.tar.gz $WORKDIR/source_deb
    cp *_source.changes $CURDIR/source_deb
    cp *.dsc $CURDIR/source_deb
    cp *.tar.gz $CURDIR/source_deb
}

build_deb(){
    if [ $DEB = 0 ]
    then
        echo "source deb package will not be created"
        return;
    fi
    if [ "x$OS" = "xrmp" ]
    then
        echo "It is not possible to build source deb here"
        exit 1
    fi
    for file in 'dsc' 'orig.tar.gz' 'changes' 'tar.gz' 
    do
        get_deb_sources $file
    done
    cd $WORKDIR
    rm -fv *.deb
    #
    export DEBIAN=$(lsb_release -sc)
    export ARCH=$(echo $(uname -m) | sed -e 's:i686:i386:g')
    if [ "x${ARCH}" = "xx86_64" ]; then
        ARCH="amd64"
    fi
    #
    echo "DEBIAN=${DEBIAN}" >> info_package.properties
    echo "ARCH=${ARCH}" >> info_package.properties
    #
    DSC=$(basename $(find . -name '*.dsc' | sort | tail -n1))
    DIRNAME=$(echo ${DSC%-1.dsc} | sed -e 's:_:-:g')
    DIR_VER=$(echo ${DSC%-1.dsc})
    #
    dpkg-source -x ${DSC}
    sed -i '/^$/d' ${DIRNAME}/debian/control
    VERSION=$(grep Version ${DIRNAME}/debian/control | awk '{print $2}')
    RELEASE=$(grep Release ${DIRNAME}/debian/control | awk '{print $2}')
    mkdir -p ${DIR_VER}-1.${DEBIAN}_${ARCH}
    mv ${DIRNAME}/debian ${DIR_VER}-1.${DEBIAN}_${ARCH}/DEBIAN
    dpkg-deb --build ${DIR_VER}-1.${DEBIAN}_${ARCH}
    
    mkdir -p ${CURDIR}/deb
    mkdir -p ${WORKDIR}/deb
    cp ${WORKDIR}/*.deb ${WORKDIR}/deb
    cp ${WORKDIR}/*.deb ${CURDIR}/deb
}

#main

CURDIR=$(pwd)
args=
WORKDIR=
SRPM=0
SDEB=0
RPM=0
DEB=0
SOURCE=0
TARBALL=0
OS_NAME=
ARCH=
OS=
INSTALL=0
BRANCH="master"
REPO="https://github.com/EvgeniyPatlan/info_packages.git"
DIR_NAME=""

parse_arguments PICK-ARGS-FROM-ARGV "$@"

if [ x${PRODUCT} = "xps-80" ]; then
    DIR_NAME=percona-server-80-info
elif [ x${PRODUCT} = "xpxc-80" ]; then
    DIR_NAME=percona-xtradb-cluster-80-info
elif [ x${PRODUCT} = "xpsmdb-40" ]; then
    DIR_NAME=percona-server-mongodb-80-info
fi
check_workdir
get_system
install_deps
get_sources
build_srpm
build_source_deb
build_rpm
build_deb
