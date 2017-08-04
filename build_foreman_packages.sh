#!/bin/bash

set -e

PACKAGE=""
BRANCH=""
PACKAGING_NAME=""

SCRIPTNAME=`basename "$0"`

# read the options
OPTS=`getopt -o n:b:p: -n $SCRIPTNAME -- "$@"`
eval set -- "$OPTS"

# extract options and their arguments into variables.
while true ; do
    case "$1" in
        -n)
            PACKAGE=$2
            shift 2 
            ;;
        -b)
            BRANCH=$2
            shift 2 
            ;;
        -p)
            PACKAGING_NAME=$2
            shift 2 
            ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

if [ -z "$PACKAGE" ]; then
    echo "Error: Package name must be given. (Option: '-n <package-name>')"
    exit 1
fi

BUILD_PATH="${PWD}"
YUM_CONF="${PWD}/yum.conf"
RPMMACROS="${PWD}/rpmmacros"
DOCKER_ENV="${PWD}/create_docker_env.sh"
PACKAGE_PATH="${BUILD_PATH}/${PACKAGE}"
PACKAGING_PATH="${BUILD_PATH}/foreman-packaging"
PKG_BUILD_PATH="${PACKAGE_PATH}/_pkg_build"
RPM_PATH="${PACKAGE_PATH}/RPM"

BRANCH_SPECIFIER="--branch master"
if [ "$BRANCH" != "" ]; then
    BRANCH_SPECIFIER="--branch $BRANCH"
fi

if [ -z "$PACKAGING_NAME" ]; then
    PACKAGING_NAME=$PACKAGE
fi

echo "Starting to build $PACKAGE with $BRANCH_SPECIFIER - PWD: $PWD"

echo "Clone ${PACKAGE}"
git clone https://github.com/theforeman/${PACKAGE}.git $BRANCH_SPECIFIER

# In this directory we will put everything so that we can build the RPM pkg
mkdir ${PKG_BUILD_PATH}
mkdir ${PKG_BUILD_PATH}/source/

if [ ! -d foreman-packaging ]; then
    echo "Clone foreman-packaging"
    git clone https://github.com/theforeman/foreman-packaging.git --branch rpm/1.15
fi

####################################################################
# Stuff to do in PACKAGING_PATH
####################################################################

cd "${PACKAGING_PATH}/${PACKAGING_NAME}"

SPEC_COUNT=`find . -name "*.spec" | wc -l` 
if [ "$SPEC_COUNT" -gt 1 ]; then
    echo "Error: There must be always exactly one spec file in ${PACKAGING_PATH}/${PACKAGE}. Found: $SPEC_COUNT";
    exit 1
fi

# there is always only one spec - exit if this is not the case
SPEC=`ls -1 *.spec`

if [ ! -f "$SPEC" ]; then
    echo "Error: Couldn't find spec file: ${SPEC}"
    exit 1;
fi

# Is it a GEM file?
IS_GEM=0
if [[ "$SPEC" == *"rubygem-"* ]]; then
    IS_GEM=1
fi

echo "Get the version from ${SPEC} of ${PACKAGE}"
VERSION=`rpmspec --query --srpm --queryformat="%{version}" ${SPEC}`
echo "Version of ${PACKAGE} is ${VERSION}"

echo "Copy real files (exclude the git annex files) to ${PKG_BUILD_PATH}"
tar -c `find . -not -xtype l` | tar -C $PKG_BUILD_PATH/source/ -x

####################################################################
# Stuff to do in PACKAGE_PATH
####################################################################

cd ${PACKAGE_PATH} 

if [ "$IS_GEM" -eq 1 ]; then
    echo "Creating gem for ${PACKAGE} with version ${VERSION}"
    gem build "${PACKAGE}.gemspec"
    PACKAGE_FILE="${PACKAGE}-${VERSION}.gem"
else
    echo "Creating tar archive: ${PACKAGE}-${VERSION}.tar.bz2"
    PACKAGE_FILE="${PACKAGE}-${VERSION}.tar.bz2"
    git archive --prefix=${PACKAGE}-${VERSION}/ HEAD | bzip2 > ${PACKAGE_FILE}
fi

mv -v $PACKAGE_FILE ${PKG_BUILD_PATH}/source/
echo "Now we have everything in $PKG_BUILD_PATH/source"

echo "Got to ${PKG_BUILD_PATH}"
cd $PKG_BUILD_PATH

echo "Copy necessary repos / spec / rpm build scripts"
cp -v ${YUM_CONF} .
cp -v ${RPMMACROS} .
cp -v source/*.spec .

echo "Creating docker_vars.rb for ${PACKAGE}"
cat <<EOF >> docker_vars.rb
#!/usr/bin/ruby

@spec = "$SPEC"
@pkg_name = "$PACKAGE"
EOF

echo "Creating Dockerfile and rpmmacros for ${PACKAGE} with erb"
${DOCKER_ENV} ./docker_vars.rb ${BUILD_PATH}

echo "Creating docker container ${PACKAGE}"
docker build -t "build_${PACKAGE}" .

mkdir -p ${RPM_PATH}/{noarch,x86_64}
chmod -R 777 ${RPM_PATH}

echo "Running docker to create RPM for ${PACKAGE}"
docker run --rm -e PKG_NAME=${PACKAGE} -v ${RPM_PATH}:/results -v ${PKG_BUILD_PATH}/source/:/source build_${PACKAGE}
