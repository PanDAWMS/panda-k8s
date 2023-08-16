#!/bin/bash
#
# pilot wrapper used for Rubin jobs
#
# https://google.github.io/styleguide/shell.xml

VERSION=20230111a-rubin

function err() {
  dt=$(date --utc +"%Y-%m-%d %H:%M:%S,%3N [wrapper]")
  echo "$dt $@" >&2
}

function log() {
  dt=$(date --utc +"%Y-%m-%d %H:%M:%S,%3N [wrapper]")
  echo "$dt $@"
}

function get_workdir {
  if [[ ${piloturl} == 'local' ]]; then
    echo $(pwd)
    return 0
  fi

  if [[ -n "${TMPDIR}" ]]; then
    templ=${TMPDIR}/rubin_XXXXXXXX
  else
    templ=$(pwd)/rubin_XXXXXXXX
  fi
  tempd=$(mktemp -d $templ)
  echo ${tempd}
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
    apfmon_fault 1
    sortie 1
  fi
}

function check_proxy() {
  if voms-proxy-info -all; then
    return
  else
    log "WARNING: error running: voms-proxy-info -all"
    err "WARNING: error running: voms-proxy-info -all"
  fi
}

function check_cvmfs() {
  local VO_LSST_SW_DIR=/cvmfs/sw.lsst.eu/linux-x86_64/lsst_distrib
  if [[ -d ${VO_LSST_SW_DIR} ]]; then
    log "Found LSST software repository: ${VO_LSST_SW_DIR}"
  else
    log "ERROR: LSST software repository NOT found: ${VO_LSST_SW_DIR}"
    log "FATAL: Failed to find LSST software repository"
    err "FATAL: Failed to find LSST software repository"
    apfmon_fault 1
    sortie 1
  fi
}

function get_pandaenvdir() {
  if [[ -z "$pandaenvtag" ]]; then
    echo "$(ls -td /cvmfs/sw.lsst.eu/linux-x86_64/panda_env/v* | head -1)"
  else
    echo "$(ls -td /cvmfs/sw.lsst.eu/linux-x86_64/panda_env/${pandaenvtag}* | head -1)"
  fi
}

function get_pandaenvdir_local() {
  if [[ -z "$pandaenvtag" ]]; then
    echo "$(ls -td /sdf/data/rubin/panda_jobs/panda_env/v* | head -1)"
  else
    echo "$(ls -td /sdf/data/rubin/panda_jobs/panda_env/${pandaenvtag}* | head -1)"
  fi
}

function setup_lsst() {
  log "Sourcing: ${pandaenvdir}/conda/install/bin/activate pilot"
  source ${pandaenvdir}/conda/install/bin/activate pilot
  # source /cvmfs/sw.lsst.eu/linux-x86_64/panda_env/v0.0.4-dev/conda/install/bin/activate
  # source activate pilot
  # RUCIO_CONFIG=/some/path/to/rucio.cfg is temporarily in site PROLOG script
  # log "rucio whoami: $(rucio whoami)"
  # log "rucio ping: $(rucio ping)"
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
  cmd="${pybin} ${pilotbase}/pilot.py -q ${qarg} -i ${iarg} -j ${jarg} ${pilotargs}"
  echo ${cmd}
}

function get_piloturl() {
  local version=$1
  local pilotdir=file://${pandaenvdir}/pilot

  if [[ -n ${piloturl} ]]; then
    echo ${piloturl}
    return 0
  fi

  if [[ ${version} == '1' ]]; then
    log "FATAL: pilot version 1 requested, not supported by this wrapper"
    err "FATAL: pilot version 1 requested, not supported by this wrapper"
    apfmon 1
    sortie 1
  elif [[ ${version} == '2' ]]; then
    log "FATAL: pilot version 2 requested, not supported by this wrapper"
    err "FATAL: pilot version 2 requested, not supported by this wrapper"
    apfmon 1
    sortie 1
  elif [[ ${version} == 'latest' ]]; then
    pilottar=${pilotdir}/pilot3.tar.gz
  elif [[ ${version} == 'current' ]]; then
    pilottar=${pilotdir}/pilot3.tar.gz
  elif [[ ${version} == '3' ]]; then
    pilottar=${pilotdir}/pilot3.tar.gz
  else
    pilottar=${pilotdir}/pilot3-${version}.tar.gz
  fi

  # pilottar=file:///sdf/data/rubin/panda_jobs/panda_env/pilot3-3.4.1.36.tar.gz
  # pilottar=file:///sdf/group/rubin/sandbox/panda_env_pilot/pilot3-3.5.1.17.tar.gz
  # pilottar=file:///sdf/group/rubin/sandbox/panda_env_pilot/pilot3-3.5.2.1.tar.gz
  # pilottar=file:///sdf/group/rubin/sandbox/panda_env_pilot/pilot3-3.5.2.29.tar.gz
  # pilottar=file:///sdf/group/rubin/sandbox/panda_env_pilot/pilot3-3.6.0.48.tar.gz

  # pilottar=file:///sdf/data/rubin/panda_jobs/panda_env_pilot/pilot3-3.6.0.103_add_wait.tar.gz
  pilottar_local=/sdf/data/rubin/panda_jobs/panda_env_pilot/pilot3-3.4.1.36-add_wait.tar.gz
  # pilottar=file:///sdf/data/rubin/panda_jobs/panda_env_pilot/pilot3-3.6.0.106_add_wait.tar.gz
  if [[ -f ${pilottar_local} ]]; then
      # log "${pilottar_local} exist. Use it"
      pilottar="file://"${pilottar_local}
      # log "pilottar=${pilottar}"
  fi
  # log "pilottar=${pilottar}"
  echo ${pilottar}
}

function get_pilot() {

  local url=$1

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
    else
      log "local pilot3.tar.gz not found so assuming already extracted"
    fi
    pilotdir=$(tar ztf pilot3.tar.gz | head -1)
    pilotbase=$(basename ${pilotdir})
    log "pilotbase: ${pilotbase}"
  else
    log "Extracting pilot from: ${url}"
    curl --connect-timeout 30 --max-time 180 -sSL ${url} | tar -xzf -
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
      log "ERROR: pilot download failed: ${url}"
      err "ERROR: pilot download failed: ${url}"
      return 1
    fi
    pilotdir=$(curl --connect-timeout 30 --max-time 180 -sSL ${url} 2>/dev/null | tar ztf - | head -1)
    pilotbase=$(basename ${pilotdir})
    export PANDA_PILOT_SOURCE=${pilotdir}
    log "PANDA_PILOT_SOURCE=${PANDA_PILOT_SOURCE}"
  fi

  if [[ -f ${pilotbase}/pilot.py ]]; then
    log "Sanity check: file ${pilotbase}/pilot.py exists OK"
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
  echo -n "running 0 ${VERSION} ${qarg} ${APFFID}:${APFCID}" > /dev/udp/148.88.67.14/28527
  resource=${GRID_GLOBAL_JOBHOST:-}
  out=$(curl -ksS --connect-timeout 10 --max-time 20 -d uuid=${UUID} \
             -d qarg=${qarg} -d state=wrapperrunning -d wrapper=${VERSION} \
             -d gtag=${GTAG} -d resource=${resource} \
             -d hid=${HARVESTER_ID} -d hwid=${HARVESTER_WORKER_ID} \
             ${APFMON}/jobs/${APFFID}:${APFCID})
  if [[ $? -eq 0 ]]; then
    log $out
  else
    err "WARNING: wrapper monitor ${UUID}"
  fi
}

function apfmon_exiting() {
  [[ ${mute} == 'true' ]] && muted && return 0
  out=$(curl -ksS --connect-timeout 10 --max-time 20 \
             -d state=wrapperexiting -d rc=$1 -d uuid=${UUID} \
             -d ids="${pandaids}" -d duration=$2 \
             ${APFMON}/jobs/${APFFID}:${APFCID})
  if [[ $? -eq 0 ]]; then
    log $out
  else
    err "WARNING: wrapper monitor ${UUID}"
  fi
}

function apfmon_fault() {
  [[ ${mute} == 'true' ]] && muted && return 0

  out=$(curl -ksS --connect-timeout 10 --max-time 20 \
             -d state=wrapperfault -d rc=$1 -d uuid=${UUID} \
             ${APFMON}/jobs/${APFFID}:${APFCID})
  if [[ $? -eq 0 ]]; then
    log $out
  else
    err "WARNING: wrapper monitor ${UUID}"
  fi
}

function trap_handler() {
  if [[ -n "${pilotpid}" ]]; then
    log "WARNING: Caught $1, signalling pilot PID: $pilotpid"
    kill -s $1 $pilotpid
    wait
  else
    log "WARNING: Caught $1 prior to pilot starting"
  fi
}

function sortie() {
  ec=$1
  if [[ $ec -eq 0 ]]; then
    state=wrapperexiting
  else
    state=wrapperfault
  fi

  log "==== wrapper stdout END ===="
  err "==== wrapper stderr END ===="

  duration=$(( $(date +%s) - ${starttime} ))
  log "${state} ec=$ec, duration=${duration}"
  
  if [[ ${mute} == 'true' ]]; then
    muted
  else
    echo -n "${state} ${duration} ${VERSION} ${qarg} ${APFFID}:${APFCID}" > /dev/udp/148.88.67.14/28527
  fi

  exit $ec
}

function get_cricopts() {
  container_opts=$(curl --silent $cricurl | grep container_options | grep -v null)
  if [[ $? -eq 0 ]]; then
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

function main() {
  #
  # Fail early, fail often^W with useful diagnostics
  #
  trap 'trap_handler SIGINT' SIGINT
  trap 'trap_handler SIGTERM' SIGTERM
  trap 'trap_handler SIGQUIT' SIGQUIT
  trap 'trap_handler SIGSEGV' SIGSEGV
  trap 'trap_handler SIGXCPU' SIGXCPU
  trap 'trap_handler SIGUSR1' SIGUSR1
  trap 'trap_handler SIGUSR2' SIGUSR2
  trap 'trap_handler SIGBUS' SIGBUS

  echo "This is Rubin pilot wrapper version: $VERSION"
  echo "Please send development requests to p.love@lancaster.ac.uk"
  echo "Wrapper timestamps are UTC"
  echo
  log "==== wrapper stdout BEGIN ===="
  err "==== wrapper stderr BEGIN ===="
  UUID=$(cat /proc/sys/kernel/random/uuid)
  apfmon_running
  log "${cricurl}"
  echo

  echo "---- Host details ----"
  echo "hostname:" $(hostname -f)
  echo "pwd:" $(pwd)
  echo "whoami:" $(whoami)
  echo "id:" $(id)
  echo "getopt -V:" $(getopt -V 2>/dev/null)
  echo "jq --version:" $(jq --version 2>/dev/null)
  if [[ -r /proc/version ]]; then
    echo "/proc/version:" $(cat /proc/version)
  fi
  echo "lsb_release:" $(lsb_release -d 2>/dev/null)

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

  echo "---- Initial environment ----"
  printenv | sort
  echo
  echo "---- PWD content ----"
  pwd
  ls -la
  echo

  echo "---- Check cvmfs area ----"
  check_cvmfs
  pandaenvdir=$(get_pandaenvdir_local)
  log "local pandaenvdir: ${pandaenvdir}"
  if [[ ! -d ${pandaenvdir} ]]; then
    pandaenvdir=$(get_pandaenvdir)
    log "pandaenvdir: ${pandaenvdir}"
  fi
  echo

  echo "---- Enter workdir ----"
  workdir=$(get_workdir)
  log "Workdir: ${workdir}"
  if [[ -f pandaJobData.out ]]; then
    log "Job description file exists PUSH mode, copying to working dir"
    log "cp pandaJobData.out $workdir/pandaJobData.out"
    cp pandaJobData.out $workdir/pandaJobData.out
  fi
  log "cd ${workdir}"
  cd ${workdir}
  echo
 
  echo "---- LSST_LOCAL_PROLOG script ----"
  if [[ -n "${LSST_LOCAL_PROLOG}" ]]; then
    if [[ -f "${LSST_LOCAL_PROLOG}" ]]; then
      log "Sourcing local site prolog: ${LSST_LOCAL_PROLOG}"
      log "Content of: ${LSST_LOCAL_PROLOG}"
      cat ${LSST_LOCAL_PROLOG}
      source ${LSST_LOCAL_PROLOG}
    else
      log "WARNING: prolog script not found, expecting LSST_LOCAL_PROLOG=${LSST_LOCAL_PROLOG}"
    fi
  fi
  echo

  echo "---- Retrieve pilot code ----"
  piloturl=$(get_piloturl ${pilotversion})
  log "Using piloturl: ${piloturl}"

  get_pilot ${piloturl}
  if [[ $? -ne 0 ]]; then
    log "FATAL: failed to get pilot code"
    err "FATAL: failed to get pilot code"
    apfmon_fault 1
    sortie 1
  fi
  echo

  # mkdir pilot3 since this is hardcoded in pilot3 store_jobid function
  mkdir -p pilot3
  
  echo "---- Shell process limits ----"
  ulimit -a
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
  echo

  echo "---- Setup LSST environ ----"
  setup_lsst
  echo

  echo "---- Check python version ----"
  check_python3
  echo 

   echo "---- Proxy Information ----"
  if [[ ${tflag} == 'true' ]]; then
    log 'Skipping proxy checks due to -t flag'
  else
    :
    # TODO sort jar issue
    # check_proxy
  fi
  echo
  
  echo "---- Job Environment ----"
  printenv | sort
  echo

  echo "---- Build pilot cmd ----"
  cmd=$(pilot_cmd)
  echo $cmd
  echo

  echo "---- Ready to run pilot ----"
  echo

  log "==== pilot stdout BEGIN ===="
  $cmd &
  pilotpid=$!
  wait $pilotpid
  pilotrc=$?
  log "==== pilot stdout END ===="
  log "==== wrapper stdout RESUME ===="
  log "pilotpid: $pilotpid"
  log "Pilot exit status: $pilotrc"
  
  log "Temp override of pilotbase to hardcoded pilot3"
  log "https://github.com/PanDAWMS/pilot3/issues/54"
  pilotbase=pilot3
  if [[ -f ${workdir}/${pilotbase}/pandaIDs.out ]]; then
    # max 30 pandaids
    pandaids=$(cat ${workdir}/${pilotbase}/pandaIDs.out | xargs echo | cut -d' ' -f-30)
    log "pandaids: ${pandaids}"
  else
    log "File not found: ${workdir}/${pilotbase}/pandaIDs.out, no payload"
    err "File not found: ${workdir}/${pilotbase}/pandaIDs.out, no payload"
    pandaids=''
  fi

  duration=$(( $(date +%s) - ${starttime} ))
  apfmon_exiting ${pilotrc} ${duration}
  

  if [[ ${piloturl} != 'local' ]]; then
      log "cleanup: rm -rf $workdir"
      rm -fr $workdir
  else 
      log "Test setup, not cleaning"
  fi

  echo "---- LSST_LOCAL_EPILOG script ----"
  if [[ -n "${LSST_LOCAL_EPILOG}" ]]; then
    if [[ -f "${LSST_LOCAL_EPILOG}" ]]; then
      log "Sourcing local site epilog: ${LSST_LOCAL_EPILOG}"
      log "Content of: ${LSST_LOCAL_EPILOG}"
      cat ${LSST_LOCAL_EPILOG}
      echo
      source ${LSST_LOCAL_EPILOG}
    else
      log "WARNING: epilog script not found, expecting LSST_LOCAL_EPILOG=${LSST_LOCAL_EPILOG}"
    fi
  fi

  sortie 0
}

function usage () {
  echo "Usage: $0 -q <queue> -r <resource> -s <site> [<pilot_args>]"
  echo
  echo "  --container (Standalone container), file to source for release setup "
  echo "  -i,   pilot type, default PR"
  echo "  -j,   job type prodsourcelabel, default 'managed'"
  echo "  -q,   panda queue"
  echo "  -r,   panda resource"
  echo "  -s,   sitename for local setup"
  echo "  -t,   pass -t option to pilot, skipping proxy check"
  echo "  --piloturl, URL of pilot code tarball"
  echo "  --pilotversion, request particular pilot version"
  echo "  --localpy, use local python"
  echo
  exit 1
}

starttime=$(date +%s)

harvesterarg=''
workflowarg=''
iarg='PR'
jarg='managed'
qarg=''
rarg=''
tflag='false'
piloturl=''
pilotversion='latest'
pilotbase='pilot3'
pandaenvtag=''
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
    --localpy)
    localpyflag=true
    shift
    ;;
    --piloturl)
    piloturl="$2"
    shift
    shift
    ;;
    --pandaenvtag)
    pandaenvtag="$2"
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

cricurl="http://pandaserver-doma.cern.ch:25085/cache/schedconfig/${sarg}.all.json"
fabricmon="http://apfmon.lancs.ac.uk/api"
if [ -z ${APFMON} ]; then
  APFMON=${fabricmon}
fi
main "$myargs"
