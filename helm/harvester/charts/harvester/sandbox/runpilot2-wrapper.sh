#!/bin/bash
#
# pilot wrapper used at CERN central pilot factories
#
# https://google.github.io/styleguide/shell.xml

VERSION=20250611a-master

function err() {
  dt=$(date --utc +"%Y-%m-%d %H:%M:%S,%3N [wrapper]")
  echo "$dt $@" >&2
}

function log() {
  dt=$(date --utc +"%Y-%m-%d %H:%M:%S,%3N [wrapper]")
  echo "$dt $@"
}

function sortie() {
  # Currently Harvester interprets exit-codes as following:
  #         1: "wrapper fault",
  #         2: "wrapper killed stuck pilot",
  #        64: "wrapper got cvmfs repos issue",
  ec=$1

  if [[ -n "${SUPERVISOR_PID}" ]]; then
    CHILD=$(ps -o pid= --ppid "$SUPERVISOR_PID")
  else
    log "No supervise_pilot process found"
  fi
  if [[ -n "${CHILD}" ]]; then
    log "cleanup supervisor_pilot $CHILD $SUPERVISOR_PID"
  else
    log "No supervise_pilot CHILD process found"
  fi
  kill -s 15 $CHILD $SUPERVISOR_PID > /dev/null 2>&1

  if [[ ${piloturl} != 'local' ]]; then
    log "cleanup: rm -rf $workdir"
    rm -fr $workdir
  else
    log "Test setup, not cleaning"
  fi

  if [[ $ec -eq 0 ]]; then
    apfmon_exiting ${ec}
  else
    apfmon_fault ${ec}
  fi

  log "==== wrapper stdout END ===="
  err "==== wrapper stderr END ===="

  exit $ec
}

function get_workdir {
  if [[ ${piloturl} == 'local' && ${harvesterflag} == 'false' ]]; then
    echo $(pwd)
    return 0
  fi

  if [[ ${harvesterflag} == 'true' ]]; then
    # test if Harvester WorkFlow is OneToMany aka "Jumbo" Jobs
    if [[ ${workflowarg} == 'OneToMany' ]]; then
      if [[ -n ${!harvesterarg} ]]; then
        templ=$(pwd)/atlas_${!harvesterarg}
        mkdir ${templ}
        echo ${templ}
        return 0
      fi
    else
      echo $(pwd)
      return 0
    fi
  fi

  if [[ -n "${OSG_WN_TMP}" ]]; then
    templ=${OSG_WN_TMP}/atlas_XXXXXXXX
  elif [[ -n "${TMPDIR}" ]]; then
    templ=${TMPDIR}/atlas_XXXXXXXX
  else
    templ=$(pwd)/atlas_XXXXXXXX
  fi
  tempd=$(mktemp -d $templ)
  if [[ $? -ne 0 ]]; then
    log "ERROR: mktemp failed: $templ"
    err "ERROR: mktemp failed: $templ"
    return 1
  fi
  echo ${tempd}
}

function check_python2() {
  pybin=$(which python2)
  if [[ $? -ne 0 ]]; then
    log "FATAL: python2 not found in PATH"
    err "FATAL: python2 not found in PATH"
    if [[ -z "${PATH}" ]]; then
      log "In fact, PATH env var is unset mon amie"
      err "In fact, PATH env var is unset mon amie"
    fi
    log "PATH content is ${PATH}"
    err "PATH content is ${PATH}"
    sortie 1
  fi

  pyver=$($pybin -c 'import sys; print("%i%02i" % (sys.version_info.major, sys.version_info.minor))')
  # we don't want python3 if requesting python2 explicitly
  if [[ ${pyver} -ge 300 ]] ; then
    log "ERROR: this site has python > 3.0, but only python2 requested"
    err "ERROR: this site has python > 3.0, but only python2 requested"
    sortie 1
  fi

  # check if native python version > 2.6
  if [[ ${pyver} -ge 206 ]] ; then
    log "Native python version is > 2.6 (${pyver})"
    log "Using ${pybin} for python compatibility"
    return
  else
    log "ERROR: this site has native python < 2.6"
    err "ERROR: this site has native python < 2.6"
    log "Native python ${pybin} is old: ${pyver}"

    # Oh dear, we're doomed...
    log "FATAL: Failed to find a compatible python, exiting"
    err "FATAL: Failed to find a compatible python, exiting"
    sortie 1
  fi
}

function setup_python3() {
  # setup python3 from ALRB, default for grid sites
  if [[ ${localpyflag} == 'true' ]]; then
    log "localpyflag is true so we skip ALRB python3"
  elif [[ ${ATLAS_LOCAL_PYTHON} == 'true' ]]; then
    # email thread 7/7/21 dealing with LRZ SUSE
    log "Env var ATLAS_LOCAL_PYTHON=true so skip ALRB python3"
  else
    log "Using ALRB to setup python3"
    if [ -z "$ATLAS_LOCAL_ROOT_BASE" ]; then
        export ATLAS_LOCAL_ROOT_BASE="${ATLAS_SW_BASE}/atlas.cern.ch/repo/ATLASLocalRootBase"
    fi
    export ALRB_LOCAL_PY3="YES"
    source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh --quiet >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
      log "FATAL: failed to source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh"
      err "FATAL: failed to source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh"
      sortie 64
    fi
    if [ -z $ALRB_pythonVersion ]; then
      lsetup -q "python pilot-default"
    else
      lsetup -q python
    fi
  fi
}

function check_python3() {
  pybin=$(which python3)
  if [[ $? -ne 0 ]]; then
    log "FATAL: python3 not found in PATH"
    err "FATAL: python3 not found in PATH"
    if [[ -z "${PATH}" ]]; then
      log "In fact, PATH env var is unset mon amie"
      err "In fact, PATH env var is unset mon amie"
    fi
    log "PATH content: ${PATH}"
    err "PATH content: ${PATH}"
    sortie 1
  fi

  pyver=$($pybin -c 'import sys; print("%i%02i" % (sys.version_info.major, sys.version_info.minor))')
  # check if python version > 3.6
  if [[ ${pyver} -ge 306 ]] ; then
    log "Python version is > 3.6 (${pyver})"
    log "Using ${pybin} for python compatibility"
  else
    log "ERROR: this site has python < 3.6"
    err "ERROR: this site has python < 3.6"
    log "Python ${pybin} is old: ${pyver}"

    # Oh dear, we're doomed...
    log "FATAL: Failed to find a compatible python, exiting"
    err "FATAL: Failed to find a compatible python, exiting"
    sortie 1
  fi
}

function check_proxy() {
  voms-proxy-info -all
  if [[ $? -ne 0 ]]; then
    log "WARNING: error running: voms-proxy-info -all"
    err "WARNING: error running: voms-proxy-info -all"
    arcproxy -I
    if [[ $? -eq 127 ]]; then
      log "FATAL: error running: arcproxy -I"
      err "FATAL: error running: arcproxy -I"
      sortie 1
    fi
  fi
}

function check_cvmfs() {
  export VO_ATLAS_SW_DIR=${VO_ATLAS_SW_DIR:-${ATLAS_SW_BASE}/atlas.cern.ch/repo/sw}

  CVMFS_BASE=${ATLAS_SW_BASE:-/cvmfs}
  targets="${CVMFS_BASE}/atlas.cern.ch/repo/ATLASLocalRootBase/logDir/lastUpdate \
           ${CVMFS_BASE}/atlas-condb.cern.ch/repo/conditions/logDir/lastUpdate \
           ${CVMFS_BASE}/atlas-nightlies.cern.ch/repo/sw/logs/lastUpdate \
           ${CVMFS_BASE}/sft.cern.ch/lcg/lastUpdate \
           ${CVMFS_BASE}/unpacked.cern.ch/logDir/lastUpdate \
           ${CVMFS_BASE}/sft-nightlies.cern.ch/lcg/lastUpdate"

  for target in ${targets}; do
    if [ $(cat ${target} | wc -l) -ge 1 ]; then
      log "${target} is accessible"
    else
      log "WARNING: ${target} not accessible or empty, pilot to handle"
      err "WARNING: ${target} not accessible or empty, pilot to handle"
    fi
  done
}

function setup_alrb() {
  export ATLAS_LOCAL_ROOT_BASE=${ATLAS_LOCAL_ROOT_BASE:-${ATLAS_SW_BASE}/atlas.cern.ch/repo/ATLASLocalRootBase}
  export ALRB_userMenuFmtSkip=YES
  export ALRB_noGridMW=${ALRB_noGridMW:-NO}

  log 'NOTE: rucio,davix,xrootd setup now done in local site setup atlasLocalSetup.sh'
  if [[ ${iarg} == "RC" ]]; then
    log 'RC pilot requested, setting ALRB_rucioVersion=testing'
    log 'RC pilot, source $ATLAS_LOCAL_ROOT_BASE/etc/ADCPilotTesting.sh' 
    source $ATLAS_LOCAL_ROOT_BASE/etc/ADCPilotTesting.sh
    export ALRB_rucioVersion=testing
  fi
  if [[ ${iarg} == "ALRB" ]]; then
    log 'ALRB pilot requested, setting ALRB env vars to testing'
    export ALRB_adcTesting=YES
  fi

  if [[ ${ALRB_noGridMW} == "YES" ]]; then
    log "Site has set ALRB_noGridMW=YES so use site native install rather than ALRB"
    if [[ ${tflag} == 'true' ]]; then
      log 'Skipping proxy checks due to -t flag'
    else
      check_vomsproxyinfo || check_arcproxy
      if [[ $? -eq 1 ]]; then
        log "FATAL: Site MW being used but proxy tools not found"
        err "FATAL: Site MW being used but proxy tools not found"
        sortie 1
      fi
    fi
  else
    log "Will use ALRB MW because ALRB_noGridMW=NO (default)"
  fi

}

function setup_local() {
  log "Looking for ${VO_ATLAS_SW_DIR}/local/setup.sh"
  if [[ -f ${VO_ATLAS_SW_DIR}/local/setup.sh ]]; then
    if [[ ${pythonversion} == '3' ]]; then
      log "Sourcing ${VO_ATLAS_SW_DIR}/local/setup.sh -s ${qarg} -p python3"
      source ${VO_ATLAS_SW_DIR}/local/setup.sh -s ${qarg} -p python3
    else
      log "Sourcing ${VO_ATLAS_SW_DIR}/local/setup.sh -s ${qarg}"
      source ${VO_ATLAS_SW_DIR}/local/setup.sh -s ${qarg}
    fi
  else
    log 'WARNING: No ATLAS local setup found'
    err 'WARNING: this site has no local setup ${VO_ATLAS_SW_DIR}/local/setup.sh'
  fi
  # OSG MW setup, skip if not using ALRB Grid MW
  if [[ ${ALRB_noGridMW} == "YES" ]]; then
    if [[ -f ${OSG_GRID}/setup.sh ]]; then
      log "Setting up OSG MW using ${OSG_GRID}/setup.sh"
      source ${OSG_GRID}/setup.sh
    else
      log 'Env var ALRB_noGridMW=NO, not sourcing ${OSG_GRID}/setup.sh'
    fi
  fi

}

function setup_shoal() {
  log "will set FRONTIER_SERVER with shoal"

  outputstr=$(env -i FRONTIER_SERVER="$FRONTIER_SERVER"  /bin/bash -l -c "shoal-client -f")
  if [[ $? -eq 0 ]] &&  [[ -n "${outputstr}" ]] ; then
    export FRONTIER_SERVER=${outputstr}
  else
    log "WARNING: shoal-client had non-zero exit code or empty output"
  fi

  log "FRONTIER_SERVER = $FRONTIER_SERVER"
}

function setup_harvester_symlinks() {
  for datafile in `find ${HARVESTER_WORKDIR} -maxdepth 1 -type l -exec /usr/bin/readlink -e {} ';'`; do
      symlinkname=$(basename $datafile)
      ln -s $datafile $symlinkname
  done
}


function check_vomsproxyinfo() {
  out=$(voms-proxy-info --version 2>/dev/null)
  if [[ $? -eq 0 ]]; then
    log "Check version: ${out}"
    return 0
  else
    log "voms-proxy-info not found"
    return 1
  fi
}

function check_arcproxy() {
  out=$(arcproxy --version 2>/dev/null)
  if [[ $? -eq 0 ]]; then
    log "Check version: ${out}"
    return 0
  else
    log "arcproxy not found"
    return 1
  fi
}

function pilot_cmd() {

  # test if not harvester job
  if [[ ${harvesterflag} == 'false' ]] ; then
    if [[ -n ${pilotversion} ]]; then
      cmd="${pybin} ${pilotbase}/pilot.py -q ${qarg} -i ${iarg} -j ${jarg} ${pilotargs}"
    else
      cmd="${pybin} ${pilotbase}/pilot.py -q ${qarg} -i ${iarg} -j ${jarg} ${pilotargs}"
    fi
  else
    # check to see if we are running OneToMany Harvester workflow (aka Jumbo Jobs)
    if [[ ${workflowarg} == 'OneToMany' ]] && [ -z ${HARVESTER_PILOT_WORKDIR+x} ] ; then
      cmd="${pybin} ${pilotbase}/pilot.py -q ${qarg} -i ${iarg} -j ${jarg} -a ${HARVESTER_PILOT_WORKDIR} ${pilotargs}"
    else
      cmd="${pybin} ${pilotbase}/pilot.py -q ${qarg} -i ${iarg} -j ${jarg} ${pilotargs}"
    fi
  fi
  echo ${cmd}
}

function sing_cmd() {
  cmd="$BINARY_PATH exec $SINGULARITY_OPTIONS --env \"APFCID=$APFCID\" \
                                              --env \"APFFID=$APFFID\" \
                                              --env \"GRID_GLOBAL_JOBHOST=$GRID_GLOBAL_JOBHOST\" \
                                              --env \"SCHEDD_NAME=$SCHEDD_NAME\" \
                                              --env \"HARVESTER_ID=$HARVESTER_ID\" \
                                              --env \"HARVESTER_WORKER_ID=$HARVESTER_WORKER_ID\" \
                                              --env \"PANDA_AUTH_ORIGIN=$PANDA_AUTH_ORIGIN\" \
                                              --env \"PANDA_AUTH_TOKEN=$PANDA_AUTH_TOKEN\" \
                                              --env \"PANDA_AUTH_TOKEN_KEY=$PANDA_AUTH_TOKEN_KEY\" \
                                              $IMAGE_PATH $0 $myargs"
  echo ${cmd}
}

function sing_env() {
  # preserve these env var in the apptainer environment
  export APPTAINERENV_X509_USER_PROXY=${X509_USER_PROXY}
  if [[ -n "${ATLAS_LOCAL_AREA}" ]]; then
    export APPTAINERENV_ATLAS_LOCAL_AREA=${ATLAS_LOCAL_AREA}
  fi
  if [[ -n "${TMPDIR}" ]]; then
    export APPTAINERENV_TMPDIR=${TMPDIR}
  fi
  if [[ -n "${RECOVERY_DIR}" ]]; then
    export APPTAINERENV_RECOVERY_DIR=${RECOVERY_DIR}
  fi
  if [[ -n "${GTAG}" ]]; then
    export APPTAINERENV_GTAG=${GTAG}
  fi
}

function get_piloturl() {
  local version=$1
  local pilotdir=file://${ATLAS_SW_BASE}/atlas.cern.ch/repo/sw/PandaPilot/tar

  if [[ -n ${piloturl} ]]; then
    echo ${piloturl}
    return 0
  fi

  if [[ ${version} == '1' ]]; then
    log "FATAL: pilot version 1 requested, not supported by this wrapper"
    err "FATAL: pilot version 1 requested, not supported by this wrapper"
    sortie 1
  elif [[ ${version} == '2' ]]; then
    log "FATAL: pilot version 2 requested, not supported by this wrapper"
    err "FATAL: pilot version 2 requested, not supported by this wrapper"
    sortie 1
  elif [[ ${version} == 'latest' ]]; then
    pilottar=${pilotdir}/pilot3.tar.gz
    pilotbase='pilot3'
  elif [[ ${version} == 'current' ]]; then
    pilottar=${pilotdir}/pilot3.tar.gz
    pilotbase='pilot3'
  elif [[ ${version} == '3' ]]; then
    pilottar=${pilotdir}/pilot3.tar.gz
    pilotbase='pilot3'
  else
    pilottar=${pilotdir}/pilot3-${version}.tar.gz
    pilotbase='pilot3'
  fi
  echo ${pilottar}
}

function get_pilot() {

  local url=$1

  # remove pending chk from Lincoln
  if [[ ${harvesterflag} == 'true' ]] && [[ ${workflowarg} == 'OneToMany' ]]; then
    cp -v ${HARVESTER_WORK_DIR}/pilot2.tar.gz .
  fi

  if [[ ${url} == 'local' ]]; then
    log "piloturl=local so download not needed"

    if [[ -f pilot3.tar.gz ]]; then
      log "local tarball pilot3.tar.gz exists OK"
      tar -xzf pilot3.tar.gz
      if [[ $? -ne 0 ]]; then
        log "ERROR: pilot extraction failed for pilot3.tar.gz"
        err "ERROR: pilot extraction failed for pilot3.tar.gz"
        return 1
      fi
    elif [[ -f pilot2.tar.gz ]]; then
      log "local tarball pilot2.tar.gz exists OK"
      log "FATAL: pilot version 2 requested, not supported by this wrapper"
      err "FATAL: pilot version 2 requested, not supported by this wrapper"
      return 1
    else
      log "local pilot[23].tar.gz not found so assuming already extracted"
    fi
  else
    curl --connect-timeout 30 --max-time 180 -sSL ${url} | tar -xzf -
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
      log "ERROR: pilot download failed: ${url}"
      err "ERROR: pilot download failed: ${url}"
      return 1
    fi
  fi

  if [[ -f ${pilotbase}/pilot.py ]]; then
    log "File ${pilotbase}/pilot.py exists OK"
    log "${pilotbase}/PILOTVERSION: $(cat ${pilotbase}/PILOTVERSION)"
    return 0
  else
    log "ERROR: ${pilotbase}/pilot.py not found"
    err "ERROR: ${pilotbase}/pilot.py not found"
    return 1
  fi
}

function muted() {
  log "apfmon messages muted"
}

function apfmon_running() {
  [[ ${mute} == 'true' ]] && muted && return 0
  log "APFCE: ${APFCE}"
  echo -n "${VERSION} \
         ${APFFID}:${APFCID} \
         running 0 \
         ${qarg:-unknown} \
         ${APFCE:-unknown} \
         ${HARVESTER_ID:-unknown} \
         ${HARVESTER_WORKER_ID:-unknown} \
         ${GTAG:-unknown}" \
         > /dev/udp/148.88.96.15/28527
}

function apfmon_exiting() {
  [[ ${mute} == 'true' ]] && muted && return 0
  log "APFCE: ${APFCE}"
  duration=$(( $(date +%s) - ${starttime} ))
  log "exiting ec=$1, duration=${duration}"
  echo -n "${VERSION} \
         ${APFFID}:${APFCID} \
         exiting \
         ${duration} \
         ${qarg:-unknown} \
         ${APFCE:-unknown} \
         ${HARVESTER_ID:-unknown} \
         ${HARVESTER_WORKER_ID:-unknown} \
         ${GTAG:-unknown}" \
         > /dev/udp/148.88.96.15/28527
}

function apfmon_fault() {
  [[ ${mute} == 'true' ]] && muted && return 0
  log "APFCE: ${APFCE}"
  duration=$(( $(date +%s) - ${starttime} ))
  log "${state} ec=$1, duration=${duration}"
  echo -n "${VERSION} \
         ${APFFID}:${APFCID} \
         fault \
         ${duration} \
         ${qarg:-unknown} \
         ${APFCE:-unknown} \
         ${HARVESTER_ID:-unknown} \
         ${HARVESTER_WORKER_ID:-unknown} \
         ${GTAG:-unknown}" \
         > /dev/udp/148.88.96.15/28527
}

function trap_handler() {
  if [[ "$1" == '18' ]]; then
    # SIGCONT caught so touch pilot log and pass signal to pilot process
    log "WARNING: trap caught signal:$1, touching pilotlog.txt and signalling pilot PID: $pilotpid"
    err "WARNING: trap caught signal:$1, touching pilotlog.txt and signalling pilot PID: $pilotpid"
    touch pilotlog.txt
    kill -s 18 $pilotpid
  fi
  if [[ -n "${pilotpid}" ]]; then
    log "WARNING: trap caught signal:$1, signalling pilot PID: $pilotpid"
    err "WARNING: trap caught signal:$1, signalling pilot PID: $pilotpid"
    kill -s $1 $pilotpid
    wait
  else
    log "WARNING: Caught $1 prior to pilot starting"
  fi
}

function get_cricopts() {
  container_opts=$(curl --silent $cricurl | grep container_options | grep -v null)
  if [[ $? -eq 0 ]]; then
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
      log "FATAL: failed to retrieve CRIC data from $cricurl"
      err "FATAL: failed to retrieve CRIC data from $cricurl"
      return 1
    fi
    cricopts=$(echo $container_opts | awk -F"\"" '{print $4}')
    echo ${cricopts}
    return 0
  else
    return 1
  fi
}

function get_catchall() {
  local result
  local content
  result=$(curl --silent $cricurl | grep catchall | grep -v null)
  if [[ $? -eq 0 ]]; then
    content=$(echo $result | awk -F"\"" '{print $4}')
    echo ${content}
    return 0
  else
    return 1
  fi
}

function get_environ() {
  local result
  local content
  result=$(curl --silent $cricurl | grep environ | grep -v null)
  if [[ $? -eq 0 ]]; then
    content=$(echo $result | awk -F"\"" '{print $4}')
    echo ${content}
    return 0
  else
    return 1
  fi
}

function get_resourcetype() {
  local result
  local content
  result=$(curl --silent $cricurl | grep resource_type | grep -v null)
  if [[ $? -eq 0 ]]; then
    content=$(echo $result | awk -F"\"" '{print $4}')
    echo ${content}
    return 0
  else
    return 1
  fi
}

function check_apptainer() {
  BINARY_PATH="${ATLAS_SW_BASE}/atlas.cern.ch/repo/containers/sw/apptainer/`uname -m`-el9/current/bin/apptainer"
  if [[ ${alma9flag} == 'true' ]]; then
    IMAGE_PATH="${ATLAS_SW_BASE}/atlas.cern.ch/repo/containers/fs/singularity/`uname -m`-almalinux9"
  else
    IMAGE_PATH="${ATLAS_SW_BASE}/atlas.cern.ch/repo/containers/fs/singularity/`uname -m`-almalinux9"
  fi
  SINGULARITY_OPTIONS="$(get_cricopts) -B ${ATLAS_SW_BASE}:/cvmfs -B $PWD --cleanenv"
  out=$(${BINARY_PATH} --version 2>/dev/null)
  if [[ $? -eq 0 ]]; then
    log "Apptainer binary found, version $out"
    log "Apptainer binary path: ${BINARY_PATH}"
  else
    log "Apptainer binary not found"
  fi
}

function check_type() {
  result=$(curl --silent $cricurl | grep container_type | grep 'singularity:wrapper')
  if [[ $? -eq 0 ]]; then
    log "CRIC container_type: singularity:wrapper found"
    return 0
  else
    log "CRIC container_type: singularity:wrapper not found"
    return 1
  fi
}

function supervise_pilot() {
  # check pilotlog.txt is being updated otherwise kill the pilot
  local PILOT_PID=$1
  local counter=0
  while true; do
    ((counter++))
    err "supervise_pilot (15 min periods counter: ${counter})"
    if [[ -f "pilotlog.txt" ]]; then
      CURRENT_TIME=$(date +%s)
      LAST_MODIFICATION=$(stat -c %Y "pilotlog.txt")
      TIME_DIFF=$(( CURRENT_TIME - LAST_MODIFICATION ))

      if [[ $TIME_DIFF -gt 3600 ]]; then
        err "CURRENT_TIME: ${CURRENT_TIME}"
        err "LAST_MODIFICATION: ${LAST_MODIFICATION}"
        err "TIME_DIFF: ${TIME_DIFF}"
        echo -n "TIME_DIFF ${TIME_DIFF} ${VERSION} ${qarg} ${APFFID}:${APFCID}" > /dev/udp/148.88.96.15/28527
        echo -n "TIME_DIFF ${TIME_DIFF} ${VERSION} ${qarg} ${HARVESTER_ID}:${HARVESTER_WORKER_ID}" > /dev/udp/148.88.96.15/28527
        log "pilotlog.txt has not been updated in the last hour. Sending SIGINT (2) signal to the pilot process."
        err "pilotlog.txt has not been updated in the last hour. Sending SIGINT (2) signal to the pilot process."
        echo -n "SIGINT 0 ${VERSION} ${qarg} ${APFFID}:${APFCID}" > /dev/udp/148.88.96.15/28527
        echo -n "SIGINT 0 ${VERSION} ${qarg} ${HARVESTER_ID}:${HARVESTER_WORKER_ID}" > /dev/udp/148.88.96.15/28527
        kill -s 2 $PILOT_PID > /dev/null 2>&1
        touch wrapper_sigint_$PILOT_PID
        sleep 180
        if kill -s 0 $PILOT_PID > /dev/null 2>&1; then
          log "The pilot process ($PILOT_PID) is still running after 3m. Sending SIGKILL (9)."
          err "The pilot process ($PILOT_PID) is still running after 3m. Sending SIGKILL (9)."
          kill -s 9 $PILOT_PID
          touch wrapper_sigkill_$PILOT_PID
        fi
        exit 2
      fi
    else
      log "pilotlog.txt does not exist (yet)"
      err "pilotlog.txt does not exist (yet)"
    fi

    # Check every 15 mins
    sleep 900
  done
}

function panda_update_worker_pilot_status() {
  log "Sending panda_update_worker_pilot_status started"
  curl -sS -o /dev/null --insecure --compressed --connect-timeout 10 --max-time 20 \
       --capath "${ATLAS_LOCAL_ROOT_BASE:-${ATLAS_SW_BASE:-/cvmfs}/atlas.cern.ch/repo/ATLASLocalRootBase}/etc/grid-security-emi/certificates" \
       --cacert "${X509_USER_PROXY}" --cert "${X509_USER_PROXY}" --key "${X509_USER_PROXY}" \
       -H "User-Agent: pilot-wrapper/${VERSION} ($(uname -sm))" \
       -H 'Accept: application/json' \
       --data-urlencode "workerID=${HARVESTER_WORKER_ID}" \
       --data-urlencode "harvesterID=${HARVESTER_ID}" \
       --data-urlencode 'status=started' \
       --data-urlencode "site=${qarg}" \
       --data-urlencode "node_id=$(hostname -f)" \
       "${pandaurl}/server/panda/updateWorkerPilotStatus"
}

function hostinfo() {
  echo
  echo "---- Host details ----"
  echo "hostname:" $(hostname -f)
  echo "pwd:" $(pwd)
  echo "whoami:" $(whoami)
  echo "id:" $(id)
  echo "getopt:" $(getopt -V 2>/dev/null)
  echo "jq:" $(jq --version 2>/dev/null)
  if [[ -r /proc/version ]]; then
    echo "/proc/version:" $(cat /proc/version)
  fi
  echo "lsb_release:" $(lsb_release -d 2>/dev/null)
  echo "SINGULARITY_ENVIRONMENT:" ${SINGULARITY_ENVIRONMENT}
  echo BASHPID: ${BASHPID}
  myargs=$@
  echo "wrapper call: $0 $myargs"
  cpuinfo_flags="flags: EMPTY"
  if [ -f /proc/cpuinfo ]; then
    cpuinfo_flags="$(grep '^flags' /proc/cpuinfo 2>/dev/null | sort -u 2>/dev/null)"
    if [ -z "${cpuinfo_flags}" ]; then
      cpuinfo_flags="flags: EMPTY"
    fi
  else
    cpuinfo_flags="flags: EMPTY"
  fi
  echo "Flags from /proc/cpuinfo:"
  echo ${cpuinfo_flags}
  echo
}

function main() {
  #
  # Fail early, fail often^W with useful diagnostics
  #
  trap 'trap_handler 2' SIGINT
  trap 'trap_handler 3' SIGQUIT
  trap 'trap_handler 7' SIGBUS
  trap 'trap_handler 10' SIGUSR1
  trap 'trap_handler 11' SIGSEGV
  trap 'trap_handler 12' SIGUSR2
  trap 'trap_handler 15' SIGTERM
  trap 'trap_handler 18' SIGCONT
  trap 'trap_handler 24' SIGXCPU

  if [[ -z ${SINGULARITY_ENVIRONMENT} ]]; then
    # SINGULARITY_ENVIRONMENT not set
    echo "This is ATLAS pilot wrapper version: $VERSION"
    echo "Please send development requests to p.love@lancaster.ac.uk"
    echo
    log "==== wrapper stdout BEGIN ===="
    err "==== wrapper stderr BEGIN ===="
    UUID=$(cat /proc/sys/kernel/random/uuid)
    #hostinfo
    echo
    echo "---- Host details ----"
    echo "hostname:" $(hostname -f)
    echo "pwd:" $(pwd)
    echo "whoami:" $(whoami)
    echo "id:" $(id)
    echo "getopt:" $(getopt -V 2>/dev/null)
    echo "jq:" $(jq --version 2>/dev/null)
    if [[ -r /proc/version ]]; then
      echo "/proc/version:" $(cat /proc/version)
    fi
    echo "lsb_release:" $(lsb_release -d 2>/dev/null)
    echo "SINGULARITY_ENVIRONMENT:" ${SINGULARITY_ENVIRONMENT}
    echo BASHPID: ${BASHPID}
    myargs=$@
    echo "wrapper call: $0 $myargs"
    cpuinfo_flags="flags: EMPTY"
    if [ -f /proc/cpuinfo ]; then
      cpuinfo_flags="$(grep '^flags' /proc/cpuinfo 2>/dev/null | sort -u 2>/dev/null)"
      if [ -z "${cpuinfo_flags}" ]; then
        cpuinfo_flags="flags: EMPTY"
      fi
    else
      cpuinfo_flags="flags: EMPTY"
    fi
    echo "Flags from /proc/cpuinfo:"
    echo ${cpuinfo_flags}
    echo
    #
    apfmon_running
    panda_update_worker_pilot_status
    log "${cricurl}"
    echo
    echo "---- Initial environment ----"
    printenv
    echo
    echo "---- PWD content ----"
    pwd
    ls -la
    echo

    # CVMFS location needs to be defined fairly early in startup
    if [[ ${cvmfsbaseflag} == 'true' ]]; then
      echo "---- Configure CVMFS base path ----"
      # Log that the CVMFS base is not the usual place
      log "CVMFS base path defined from commandline: ${cvmfsbasearg}"
      echo
    fi
    export ATLAS_SW_BASE=${cvmfsbasearg}

    echo "---- Check singularity details  ----"
    cric_opts=$(get_cricopts)
    if [[ $? -eq 0 ]]; then
      log "CRIC container_options: $cric_opts"
    else
      log "FATAL: failed to get CRIC container_options"
      err "FATAL: failed to get CRIC container_options"
      sortie 1
    fi

    check_type
    if [[ $? -eq 0 ]]; then
      use_singularity=true
      log "container_type contains singularity:wrapper, so use_singularity=true"
    else
      use_singularity=false
    fi

    if [[ ${use_singularity} = true ]]; then
      # check if already in SINGULARITY environment
      log 'SINGULARITY_ENVIRONMENT is not set'
      sing_env
      log 'Setting SINGULARITY_env'
      check_apptainer
      export ALRB_noGridMW=NO
      cmd=$(sing_cmd)
      echo "cmd: $cmd"
      echo
      log '==== singularity stdout BEGIN ===='
      err '==== singularity stderr BEGIN ===='
      $cmd &
      singpid=$!
      wait $singpid
      singrc=$?
      log "singularity return code: $singrc"
      log '==== singularity stdout END ===='
      err '==== singularity stderr END ===='
      log "==== wrapper stdout END ===="
      err "==== wrapper stderr END ===="
      exit $singrc
    else
      log 'Will NOT use singularity, at least not from the wrapper'
    fi
    echo
  else
    log 'SINGULARITY_ENVIRONMENT is set, run basic setup'
    export ALRB_noGridMW=NO
    # Ensure that the ATLAS_SW_BASE gets defined to /cvmfs inside of
    # singularity/apptainer.
    export ATLAS_SW_BASE=/cvmfs
    df -h
  fi
  echo

  echo "---- Enter workdir ----"
  workdir=$(get_workdir)
  if [[ $? -ne 0 ]]; then
    log "FATAL: error with get_workdir"
    err "FATAL: error with get_workdir"
    sortie 1
  fi
  log "Workdir: ${workdir}"
  if [[ -f pandaJobData.out ]]; then
    log "Copying job description to working dir"
    cp pandaJobData.out $workdir/pandaJobData.out
  fi
  if [[ -f ${PANDA_AUTH_TOKEN} ]]; then
    log "Copying PanDA auth token to working dir"
    cp ${PANDA_AUTH_TOKEN} $workdir/${PANDA_AUTH_TOKEN}
  fi
  log "cd ${workdir}"
  cd ${workdir}
  if [[ ${harvesterflag} == 'true' ]]; then
        export HARVESTER_PILOT_WORKDIR=${workdir}
        log "Define HARVESTER_PILOT_WORKDIR : ${HARVESTER_PILOT_WORKDIR}"
  fi
  echo

  echo "---- Retrieve pilot code ----"
  piloturl=$(get_piloturl ${pilotversion})
  log "Using piloturl: ${piloturl}"

  log "Only supporting pilot3 so pilotbase directory: pilot3"
  pilotbase='pilot3'
  echo

  get_pilot ${piloturl}
  if [[ $? -ne 0 ]]; then
    log "FATAL: failed to get pilot code, from node: $(hostname -f)"
    err "FATAL: failed to get pilot code, from node: $(hostname -f)"
    sortie 64
  fi
  echo

  if [[ ${containerflag} == 'true' ]]; then
    log 'Skipping defining VO_ATLAS_SW_DIR due to --container flag'
    log 'Skipping defining ATLAS_LOCAL_ROOT_BASE due to --container flag'
  else
    export VO_ATLAS_SW_DIR=${VO_ATLAS_SW_DIR:-${ATLAS_SW_BASE}/atlas.cern.ch/repo/sw}
    export ATLAS_LOCAL_ROOT_BASE=${ATLAS_LOCAL_ROOT_BASE:-${ATLAS_SW_BASE}/atlas.cern.ch/repo/ATLASLocalRootBase}
  fi
  echo

  echo "---- Shell process limits ----"
  ulimit -a
  echo

  echo "---- Check cvmfs area ----"
  if [[ ${containerflag} == 'true' ]]; then
    log 'Skipping Check cvmfs area due to --container flag'
  else
    check_cvmfs
  fi
  echo

  echo "--- Bespoke environment from CRIC ---"
  result=$(get_environ)
  if [[ $? -eq 0 ]]; then
    if [[ -z ${result} ]]; then
      log 'CRIC environ field: <empty>'
    else
      log 'CRIC environ content'
      log "export ${result}"
      export ${result}
    fi
  else
    log 'No content found in CRIC environ'
  fi
  resource_type=$(get_resourcetype)
  echo

  echo "---- Setup ALRB ----"
  if [[ ${containerflag} == 'true' ]]; then
    log 'Skipping Setup ALRB due to --container flag'
  else
    :
    setup_alrb
  fi
  echo

  echo "---- Check python version ----"
  if [[ ${pythonversion} == '3' ]]; then
    log "python3 selected from cmdline"
    setup_python3
    check_python3
  else
    log "Default python2 selected from cmdline"
    check_python2
  fi
  echo

  echo "---- Setup local ATLAS ----"
  if [[ ${containerflag} == 'true' ]]; then
    log 'Skipping Setup local ATLAS due to --container flag'
  else
    setup_local
  fi
  echo

  echo "---- Setup logstash ----"
  log 'Running lsetup logstash'
  lsetup -q logstash
  echo

  echo "---- Setup psutil ----"
  log 'Running lsetup psutil'
  lsetup -q psutil
  echo

  echo "---- Setup stomp ----"
  result=$(get_catchall)
  if [[ $? -eq 0 ]]; then
    if grep -q "messaging=stomp" <<< "$result"; then
      log 'Stomp requested via CRIC catchall, running lsetup stomp'
      lsetup -q stomp
    else
      log 'Stomp not requested in CRIC catchall'
    fi
  else
    log 'No content found in CRIC catchall'
  fi
  echo


  if [[ ${harvesterflag} == 'true' ]]; then
    echo "---- Create symlinks to input data ----"
    log 'Create to symlinks to input data from harvester info'
    setup_harvester_symlinks
    echo
  fi

  if [[ "${shoalflag}" == 'true' ]]; then
    echo "--- Setup shoal ---"
    setup_shoal
    echo
  fi

  echo "---- Proxy Information ----"
  if [[ ${tflag} == 'true' ]]; then
    log 'Skipping proxy checks due to -t flag'
  else
    check_proxy
  fi

  echo "---- Job Environment ----"
  printenv
  echo
  if [[ -n ${ATLAS_LOCAL_AREA} ]]; then
    log "Content of $ATLAS_LOCAL_AREA/setup.sh.local"
    cat $ATLAS_LOCAL_AREA/setup.sh.local
    echo
  else
    log "Empty: \$ATLAS_LOCAL_AREA"
    echo
  fi

  echo "---- Build pilot cmd ----"
  cmd=$(pilot_cmd)
  echo $cmd
  echo

  echo "---- Ready to run pilot ----"
  echo

  log "==== pilot stdout BEGIN ===="
  $cmd &
  pilotpid=$!
  supervise_pilot ${pilotpid} &
  SUPERVISOR_PID=$!
  err "Started supervisor process ($SUPERVISOR_PID) (watching ${pilotpid})" 
  wait $pilotpid >/dev/null 2>&1
  pilotrc=$?
  log "==== pilot stdout END ===="
  log "==== wrapper stdout RESUME ===="
  log "pilotpid: $pilotpid"
  log "Pilot exit status: $pilotrc"

  if [[ -f ${workdir}/${pilotbase}/pandaIDs.out ]]; then
    # max 30 pandaids
    pandaids=$(cat ${workdir}/${pilotbase}/pandaIDs.out | xargs echo | cut -d' ' -f-30)
    log "pandaids: ${pandaids}"
  else
    log "File not found: ${workdir}/${pilotbase}/pandaIDs.out, no payload"
    err "File not found: ${workdir}/${pilotbase}/pandaIDs.out, no payload"
    pandaids=''
  fi

  # pilot handling of signals:
  # errors.KILLSIGNAL: [137, "General kill signal"],  # Job terminated by unknown kill signal
  # errors.SIGTERM: [143, "Job killed by signal: SIGTERM"],  # 128+15
  # errors.SIGQUIT: [131, "Job killed by signal: SIGQUIT"],  # 128+3
  # errors.SIGSEGV: [139, "Job killed by signal: SIGSEGV"],  # 128+11
  # errors.SIGXCPU: [152, "Job killed by signal: SIGXCPU"],  # 128+24
  # errors.SIGUSR1: [138, "Job killed by signal: SIGUSR1"],  # 128+10
  # errors.SIGINT: [130, "Job killed by signal: SIGINT"],  # 128+2
  # errors.SIGBUS: [135, "Job killed by signal: SIGBUS"]   # 128+7


  if [[ $pilotrc -eq 130 ]]; then
    # killed by supervisor SIGINT so use exitcode 2
    sortie 2
  elif [[ $pilotrc -eq 143 ]]; then
    # killed by SIGTERM, presumably LRMS
    sortie 1
  elif [[ $pilotrc -eq 137 ]]; then
    if [[ -f "wrapper_sigkill_$pilotpid" ]]; then
      err "Found: wrapper_sigkill_$pilotpid, so killed by wrapper"
      # killed by wrapper SIGKILL
      sortie 2
    else
      # killed by some other SIGKILL, presumably LRMS
      err "Not found: wrapper_sigkill_$pilotpid, so not killed by wrapper"
      sortie 1
    fi
  elif [[ $pilotrc -eq 64 ]]; then
    sortie 64
  elif [[ $pilotrc -eq 80 ]]; then
    log "WARNING: pilot exitcode=80, proxy lifetime too short"
    err "WARNING: pilot exitcode=80, proxy lifetime too short"
    sortie 80
  elif [[ $pilotrc -eq 82 ]]; then
    log "WARNING: pilot exitcode=82, no payload"
    err "WARNING: pilot exitcode=82, no payload"
    if [[ ${resource_type} == "hpc_special" ]]; then
      sortie 82
    else
      sortie 0
    fi
  elif [[ $pilotrc -ne 0 ]]; then
    log "WARNING: pilot exitcode non-zero: ${pilotrc}"
    err "WARNING: pilot exitcode non-zero: ${pilotrc}"
    sortie $pilotrc
  fi

  sortie 0
}

function usage () {
  echo "Usage: $0 -q <queue> -r <resource> -s <site> [<pilot_args>]"
  echo
  echo "  --container (Standalone container), file to source for release setup "
  echo "  --cvmfsbase (CVMFSExec), path to CVMFS base, default '/cvmfs'"
  echo "  --alma9 use alma9 container image"
  echo "  --harvester (Harvester at HPC edge), NodeID from HPC batch system "
  echo "  -i,   pilot type, default PR"
  echo "  -j,   job type prodsourcelabel, default 'managed'"
  echo "  -q,   panda queue"
  echo "  -r,   panda resource"
  echo "  -s,   sitename for local setup"
  echo "  -t,   pass -t option to pilot, skipping proxy check"
  echo "  -S,   setup shoal client"
  echo "  --piloturl, URL of pilot code tarball"
  echo "  --pilotversion, request particular pilot version"
  echo "  --pythonversion,   valid values '2' (default), and '3'"
  echo "  --localpy, skip ALRB setup and use local python"
  echo
  exit 1
}

starttime=$(date +%s)

containerflag='false'
containerarg=''
cvmfsbaseflag='false'
if [ -z ${ATLAS_SW_BASE} ]; then 
  cvmfsbasearg='/cvmfs'
else   
  cvmfsbasearg="$ATLAS_SW_BASE"
fi
alma9flag='false'
harvesterflag='false'
harvesterarg=''
workflowarg=''
iarg='PR'
jarg='managed'
qarg=''
rarg=''
shoalflag='false'
localpyflag='false'
tflag='false'
#pandaurl='http://pandaserver.cern.ch:25085'
pandaurl='https://pandaserver.cern.ch:25443'
piloturl=''
pilotversion='latest'
pilotbase='pilot3'
pythonversion='3'
mute='false'
myargs="$@"

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -h|--help)
    usage
    shift
    shift
    ;;
    --container)
    containerflag='true'
    #containerarg="$2"
    #shift
    shift
    ;;
    --cvmfsbase)
    cvmfsbaseflag='true'
    cvmfsbasearg="$2"
    shift
    shift
    ;;
    --alma9)
    alma9flag='true'
    shift
    ;;
    --harvester)
    harvesterflag='true'
    harvesterarg="$2"
    mute='true'
    pandaurl='https://pandaserver.cern.ch:25443'
    piloturl='local'
    shift
    shift
    ;;
    --harvester_workflow)
    harvesterflag='true'
    workflowarg="$2"
    shift
    shift
    ;;
    --mute)
    mute='true'
    shift
    ;;
    --pilotversion)
    pilotversion="$2"
    shift
    shift
    ;;
    --pythonversion)
    pythonversion="$2"
    shift
    shift
    ;;
    --piloturl)
    piloturl="$2"
    shift
    shift
    ;;
    -i)
    iarg="$2"
    shift
    shift
    ;;
    -j)
    jarg="$2"
    shift
    shift
    ;;
    -q)
    qarg="$2"
    shift
    shift
    ;;
    -r)
    rarg="$2"
    shift
    shift
    ;;
    -s)
    sarg="$2"
    shift
    shift
    ;;
    --localpy)
    localpyflag=true
    shift
    ;;
    -S|--shoal)
    shoalflag=true
    shift
    ;;
    -t)
    tflag='true'
    POSITIONAL+=("$1") # save it in an array for later
    shift
    ;;
    *)
    POSITIONAL+=("$1") # save it in an array for later
    shift
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if [ -z "${qarg}" ]; then usage; exit 1; fi

pilotargs="$@"

if [[ -f queuedata.json ]]; then
  cricurl="file://${PWD}/queuedata.json"
else
  cricurl="http://pandaserver.cern.ch:25085/cache/schedconfig/${qarg}.all.json"
fi

fabricmon="http://apfmon.lancs.ac.uk/api"
if [ -z ${APFMON} ]; then
  APFMON=${fabricmon}
fi
if [[ -n "${GRID_GLOBAL_JOBHOST}" ]]; then
  # ARCCE
  declare -g APFCE="${GRID_GLOBAL_JOBHOST}"
elif [[ -n "${SCHEDD_NAME}" ]]; then
  # HTCONDORCE
  declare -g APFCE="${SCHEDD_NAME}"
elif [[ -n "${CONDORCE_COLLECTOR_HOST}" ]]; then
  # HTCONDORCE
  declare -g APFCE="${CONDORCE_COLLECTOR_HOST%:*}"
else
  declare -g APFCE="unknown"
fi
main "$myargs"
