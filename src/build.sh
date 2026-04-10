#! /bin/bash

################################################################################
# Build
################################################################################

# Set up shell
if [ "$(echo ${VERBOSE} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
    set -x                      # Output commands
fi
set -u -e                       # Abort on errors, error on unset variable reference

# parse make arguments
set -- $MAKEFLAGS
MAX_JOBS=1
JOBSERVER_AUTH=
for o in "$@"; do
  case $o in 
    (  --jobserver-auth=* )
      JOBSERVER_AUTH=${o#--jobserver-auth=}
    ;;
    ( -j* )
      MAX_JOBS=${o#-j*}
    ;;
    ( -- )
      break
    ;;
  esac
done

# functions to get some job tokens from make
function return_tokens() {
  local JOBSERVER_FILE=
  if [ -n "$JOBSERVER_AUTH" ] && [ -n "$JOBSERVER_TOKENS" ]; then
    case $JOBSERVER_AUTH in 
      ( fifo:* )
        JOBSERVER_FILE=${JOBSERVER_AUTH#fifo:}
      ;;
      ( *,* )
        # /dev/fd/ emulated by bash (if not by the OS)
        JOBSERVER_FILE=/dev/fd/${JOBSERVER_AUTH#*,} # read handle of pipe
      ;;
    esac
    if [ -n "$JOBSERVER_FILE" ]; then
      echo -n $JOBSERVER_TOKENS >$JOBSERVER_FILE
    fi
  fi
}

function maybe_get_tokens() {
  local JOBSERVER_FILE=
  if [ -n "$JOBSERVER_AUTH" ];  then
    case $JOBSERVER_AUTH in 
      ( fifo:* )
        JOBSERVER_FILE=${JOBSERVER_AUTH#fifo:}
      ;;
      ( *,* )
        # /dev/fd/ emulated by bash (if not by the OS)
        JOBSERVER_FILE=/dev/fd/${JOBSERVER_AUTH#%,*} # write handle of pipe
      ;;
    esac
    if [ -n "$JOBSERVER_FILE" ]; then
      set +e # read sets error code on timeout, which is not an error
      read -r -N $(( $MAX_JOBS - 1)) -t 5 JOBSERVER_TOKENS <$JOBSERVER_FILE
      set -e
    fi
  fi
}

# set up parallel build options is parallel builds are requested
if [ -n "$MAX_JOBS" ]; then
  JOBSERVER_TOKENS=
  # wait for 5 seconds to get extra tokens for up MAX_JOBS jobs
  trap return_tokens EXIT
  maybe_get_tokens
  # one job is for "free" since it represents this process
  JOBS_OPT=-j$(( ${#JOBSERVER_TOKENS} + 1 ))
else # no maximum
  JOBS_OPT=
fi


# Set locations
THORN=Boost
NAME=boost_1_84_0
SRCDIR="$(dirname $0)"
BUILD_DIR=${SCRATCH_BUILD}/build/${THORN}
if [ -z "${BOOST_INSTALL_DIR}" ]; then
    INSTALL_DIR=${SCRATCH_BUILD}/external/${THORN}
else
    echo "Installing Boost into ${BOOST_INSTALL_DIR} "
    INSTALL_DIR=${BOOST_INSTALL_DIR}
fi
DONE_FILE=${SCRATCH_BUILD}/done/${THORN}
BOOST_DIR=${INSTALL_DIR}

# Set up environment
unset LIBS
if echo '' ${ARFLAGS} | grep 64 > /dev/null 2>&1; then
    export OBJECT_MODE=64
fi

echo "Boost: Preparing directory structure..."
cd ${SCRATCH_BUILD}
mkdir build external done 2> /dev/null || true
rm -rf ${BUILD_DIR} ${INSTALL_DIR}
mkdir ${BUILD_DIR} ${INSTALL_DIR}

echo "Boost: Unpacking archive..."
pushd ${BUILD_DIR}
${TAR?} xzf ${SRCDIR}/../dist/${NAME}-stripped.tar.gz

echo "Boost: Configuring..."
cd ${NAME}
B2_OPTS=--without-python
if [ -n "${HAVE_CAPABILITY_MPI}" ]; then
  echo 'using mpi ;' > user-config.jam
fi
./bootstrap.sh --prefix=${BOOST_DIR}

echo "Boost: Building..."
./b2 ${JOBS_OPT} ${B2_OPTS} link=static

echo "Boost: Installing..."
./b2 install ${B2_OPTS} link=static
popd

echo "Boost: Cleaning up..."
rm -rf ${BUILD_DIR}

date > ${DONE_FILE}
echo "Boost: Done."
