#! /bin/bash

################################################################################
# Prepare
################################################################################

# Set up shell
if [ "$(echo ${VERBOSE} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
    set -x                      # Output commands
fi
set -e                          # Abort on errors

. $CCTK_HOME/lib/make/bash_utils.sh

# Take care of requests to build the library in any case
BOOST_DIR_INPUT=$BOOST_DIR
if [ "$(echo "${BOOST_DIR}" | tr '[a-z]' '[A-Z]')" = 'BUILD' ]; then
    BOOST_BUILD=yes
    BOOST_DIR=
else
    BOOST_BUILD=
fi

# Try to find the library if build isn't explicitly requested
if [ -z "${BOOST_BUILD}" ]; then
    # look for the same libraries David's Boost provided, skip libboost_system
    # since it has been removed in new versions
    find_lib BOOST boost 1 1.0 "boost_atomic boost_filesystem boost_math_c99 boost_math_c99f boost_math_c99l boost_math_tr1 boost_math_tr1f boost_math_tr1l" "boost/atomic.hpp boost/filesystem.hpp boost/math/constants/constants.hpp boost/math/tr1.hpp boost/system.hpp" "$BOOST_DIR"
fi

THORN=Boost

################################################################################
# Build
################################################################################

if [ -n "$BOOST_BUILD" -o -z "${BOOST_DIR}" ]; then
    echo "BEGIN MESSAGE"
    echo "Using bundled Boost..."
    echo "END MESSAGE"
    
    check_tools "tar patch"

    # Set locations
    BUILD_DIR=${SCRATCH_BUILD}/build/${THORN}
    if [ -z "${BOOST_INSTALL_DIR}" ]; then
        INSTALL_DIR=${SCRATCH_BUILD}/external/${THORN}
    else
        echo "BEGIN MESSAGE"
        echo "Installing Boost into ${BOOST_INSTALL_DIR} "
        echo "END MESSAGE"
        INSTALL_DIR=${BOOST_INSTALL_DIR}
    fi
    BOOST_BUILD=1
    BOOST_DIR=${INSTALL_DIR}
    BOOST_INC_DIRS="$BOOST_DIR/include"
    BOOST_LIB_DIRS="$BOOST_DIR/lib"
    # we build libboost_system (still present in 1.84)
    BOOST_LIBS="boost_atomic boost_filesystem boost_math_c99 boost_math_c99f boost_math_c99l boost_math_tr1 boost_math_tr1f boost_math_tr1l boost_system"
else
    BOOST_BUILD=
    DONE_FILE=${SCRATCH_BUILD}/done/${THORN}
    if [ ! -e ${DONE_FILE} ]; then
        mkdir ${SCRATCH_BUILD}/done 2> /dev/null || true
        date > ${DONE_FILE}
    fi
fi

################################################################################
# Configure Cactus
################################################################################

# Pass configuration options to build script
echo "BEGIN MAKE_DEFINITION"
echo "BOOST_BUILD       = ${BOOST_BUILD}"
echo "BOOST_INSTALL_DIR = ${BOOST_INSTALL_DIR}"
echo "END MAKE_DEFINITION"

set_make_vars "BOOST" "$BOOST_LIBS" "$BOOST_LIB_DIRS" "$BOOST_INC_DIRS"

# Pass options to Cactus
echo "BEGIN MAKE_DEFINITION"
echo "BOOST_DIR      = ${BOOST_DIR}"
echo "BOOST_INC_DIRS = ${BOOST_INC_DIRS}"
echo "BOOST_LIB_DIRS = ${BOOST_LIB_DIRS}"
echo "BOOST_LIBS     = ${BOOST_LIBS}"
echo "END MAKE_DEFINITION"

echo 'INCLUDE_DIRECTORY $(BOOST_INC_DIRS)'
echo 'LIBRARY_DIRECTORY $(BOOST_LIB_DIRS)'
echo 'LIBRARY           $(BOOST_LIBS)'
