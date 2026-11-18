#!/bin/bash
### --ntasks-total=8 --ntasks=1 --cpus-per-task=1 --mem-per-cpu=4000

ntasks_total=1
ntasks=-1
cpus_per_task=-1
mem_per_cpu=-1

myargs="$@"

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    --ntasks-total)
    ntasks_total="$2"
    shift
    shift
    ;;
    --ntasks)
    ntasks="$2"
    shift
    shift
    ;;
    --cpus-per-task)
    cpus_per_task="$2"
    shift
    shift
    ;;
    --mem-per-cpu)
    mem_per_cpu="$2"
    shift
    shift
    ;;
    *)
    POSITIONAL+=("$1") # save it in an array for later
    shift
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

pilotargs="$@"

cmd="srun"
# if [[ $ntasks -gt 0 ]]; then
#    cmd="$cmd --ntasks $ntasks"
# fi
if [[ ${cpus_per_task} -gt 0 ]]; then
    cmd="$cmd --cpus-per-task ${cpus_per_task}"
fi
if [[ ${mem_per_cpu} -gt 0 ]]; then
    cmd="$cmd --mem-per-cpu ${mem_per_cpu}"
fi

latest=$(ls -td /cvmfs/sw.lsst.eu/almalinux-x86_64/panda_env/v* | head -1)
pandaenvdir=${latest}
# pandaenvdir=/cvmfs/sw.lsst.eu/almalinux-x86_64/panda_env/v1.0.17/

export PANDA_ENV_PILOT_DIR=${pandaenvdir}

echo "pandaenvdir: ${pandaenvdir}"
echo "PANDA_ENV_PILOT_DIR: ${PANDA_ENV_PILOT_DIR}"

rucio_cfg=${pandaenvdir}/rucio/rucio-rubin-dev.cfg

# export RUCIO_CONFIG=/cvmfs/sw.lsst.eu/linux-x86_64/panda_env/v1.0.9/conda/install/envs/pilot/etc/rucio.cfg.atlas.client.template
export RUCIO_CONFIG=$rucio_cfg

pilot_cfg=${pandaenvdir}/pilot/pilot_default.cfg
if [[ -f ${pilot_cfg} ]]; then
    if [[ -z "${HARVESTER_PILOT_CONFIG}" ]]; then
      export HARVESTER_PILOT_CONFIG=${pilot_cfg}
    fi
fi

export PILOT_ES_EXECUTOR_TYPE=fineGrainedProc

# https://rubin-panda-server-dev.slac.stanford.edu:8443/cache/schedconfig/{computingSite}.all.json
# https://datalake-cric.cern.ch/cache/schedconfig/{pandaqueue}.json
# https://datalake-cric.cern.ch/api/atlas/ddmendpoint/query/?json

queue_url=${pandaenvdir}/cric/datalake-cric-pandaqueue.json
storage_url=${pandaenvdir}/cric/datalake-cric-ddm.json
if [[ -f ${queue_url} ]]; then
    if [[ -z "${QUEUEDATA_SERVER_URL}" ]]; then
      export QUEUEDATA_SERVER_URL=${queue_url}
    fi
fi
if [[ -f ${storage_url} ]]; then
    if [[ -z "${STORAGEDATA_SERVER_URL}" ]]; then
      export STORAGEDATA_SERVER_URL=${storage_url}
    fi
fi

echo "QUEUEDATA_SERVER_URL: ${QUEUEDATA_SERVER_URL}"
echo "STORAGEDATA_SERVER_URL: ${STORAGEDATA_SERVER_URL}"
# env

echo


piloturl=""
local_pilot=/sdf/data/rubin/panda_jobs/panda_env_pilot/pilot3.tar.gz
if [[ -f ${local_pilot} ]]; then
    piloturl="--piloturl file://${local_pilot}"
fi

# check if there is a local dev pilot
pilot_wrapper_local=/sdf/data/rubin/panda_jobs/panda_env_pilot/pilot_wrapper/rubin-wrapper.sh
if [[ -f ${pilot_wrapper_local} ]]; then
    # pilot_wrapper_cmd="${pilot_wrapper_local} ${piloturl} $@ --realtime-logging-server logserver='google-cloud-logging;https://google:80'"
    pilot_wrapper_cmd="${pilot_wrapper_local} ${piloturl} $@ "
else
    # cmd="$cmd --export=ALL /cvmfs/sw.lsst.eu/linux-x86_64/panda_env/v1.0.9/pilot/wrapper/rubin-wrapper.sh $@"
    # pilot_wrapper_cmd="${pandaenvdir}/pilot/wrapper/rubin-wrapper.sh ${piloturl} --pandaenvtag v1.0.17 $@ --realtime-logging-server logserver='google-cloud-logging;https://google:80'"
    pilot_wrapper_cmd="${pandaenvdir}/pilot/wrapper/rubin-wrapper.sh ${piloturl} $@ "
fi
# echo $cmd
# echo $pilot_wrapper_cmd
echo 

# ntasks=${ntasks_total}
# for i in $(seq 1 $ntasks); do
#    run_command="$cmd ${pilot_wrapper_cmd}" 
#    $run_cmd | sed -e "s/^/pilot_$i: /"  &
# done
# 
# wait

cat <<EOF > my_panda_run_script
#!/bin/bash

# Ensure SLURM_PROCID is available per task
echo "Task started: pilot_\${SLURM_PROCID} on $(hostname)"

pwd
ls

source $latest/setup_panda_idds_client.sh

# curl https://s3.echo.stfc.ac.uk/lsst-drp-config/butler-repos-index.yaml

if ! command -v python3 >/dev/null 2>&1; then
    alias python3=python
fi

# echo ${pilot_wrapper_cmd} | sed -e "s/^/pilot_\${SLURM_PROCID}: /"
echo

${pilot_wrapper_cmd} | sed -e "s/^/pilot_\${SLURM_PROCID}: /"

EOF


chmod +x my_panda_run_script

echo "my_panda_run_script:"
cat my_panda_run_script

# echo $cmd --export=ALL --ntasks=${ntasks_total} --cpu-bind=none ./my_panda_run_script
# echo

echo "LSST_LOCAL_PROLOG: ${LSST_LOCAL_PROLOG}"

if [[ -n "${LSST_LOCAL_PROLOG}" && -f "${LSST_LOCAL_PROLOG}" ]]; then
    echo "cat LSST_LOCAL_PROLOG:"
    cat "${LSST_LOCAL_PROLOG}"
    # source ${LSST_LOCAL_PROLOG}
    echo "end LSST_LOCAL_PROLOG"
else
    echo "LSST_LOCAL_PROLOG is not set or file does not exist"
fi

# Not using container
# $cmd --export=ALL --ntasks=${ntasks_total} --cpu-bind=none ./my_panda_run_script

# Using container
# IMAGE=/cvmfs/sw.lsst.eu/containers/apptainer/x86_64/almalinux/lsst_distrib/w_2026_28
IMAGE=/cvmfs/singularity.opensciencegrid.org/opensciencegrid/osgvo-el9:latest

BIND_OPTS=(
    --bind /cvmfs
    --bind /tmp
    --bind "$HOME":"$HOME"
    --bind "$PWD":"$PWD"
)

# Bind optional filesystems if they exist
for dir in /sdf /lscratch /pbs /sps /etc/grid-security /etc/lsst /cephfs /pool_1 /pool_2; do
    if [[ -d "$dir" ]]; then
        BIND_OPTS+=(--bind "$dir")
    fi
done

ENV_OPTS=(
    --env "PANDA_ENV_PILOT_DIR=$PANDA_ENV_PILOT_DIR"
    --env "RUCIO_CONFIG=$RUCIO_CONFIG"
    --env "HARVESTER_PILOT_CONFIG=$HARVESTER_PILOT_CONFIG"
    --env "PILOT_ES_EXECUTOR_TYPE=$PILOT_ES_EXECUTOR_TYPE"
    --env "QUEUEDATA_SERVER_URL=$QUEUEDATA_SERVER_URL"
    --env "STORAGEDATA_SERVER_URL=$STORAGEDATA_SERVER_URL"
    --env "LSST_LOCAL_PROLOG=$LSST_LOCAL_PROLOG"
    --env "HOME=$HOME"
    --env "OIDC_AUTH_DIR=$PWD/none"
    --env "PANDA_AUTH_TOKEN=$PANDA_AUTH_TOKEN"
    --env "PANDA_AUTH_ORIGIN=$PANDA_AUTH_ORIGIN"
)

CMD=(
    $cmd
    --export=ALL
    --ntasks="${ntasks_total}"
    --cpu-bind=none
    /cvmfs/oasis.opensciencegrid.org/mis/apptainer/bin/apptainer
    exec
    "${BIND_OPTS[@]}"
    "${ENV_OPTS[@]}"
    --pwd "$PWD"
    "$IMAGE"
    ./my_panda_run_script
)

echo "Running command:"
printf '%q ' "${CMD[@]}"
echo

"${CMD[@]}"
