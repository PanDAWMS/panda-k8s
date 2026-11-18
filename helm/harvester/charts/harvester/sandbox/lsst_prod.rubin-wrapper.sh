#!/bin/bash
#
# pilot wrapper used for Rubin jobs
#

latest=$(ls -td /cvmfs/sw.lsst.eu/almalinux-x86_64/panda_env/v* | head -1)
pandaenvdir=${latest}

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

echo "check proxy"
voms-proxy-info -all
echo

piloturl=""
local_pilot=/sdf/data/rubin/panda_jobs/panda_env_pilot/prod_pilot3.tar.gz
if [[ -f ${local_pilot} ]]; then
    piloturl="--piloturl file://${local_pilot}"
fi

##### cmd="${pandaenvdir}/pilot/wrapper/rubin-wrapper.sh ${piloturl} --pandaenvtag v1.0.17 $@ --realtime-logging-server logserver='google-cloud-logging;https://google:80'"
cmd="${pandaenvdir}/pilot/wrapper/rubin-wrapper.sh ${piloturl} $@ "

# Not using container
# echo $cmd
# $cmd

# Using container
cat <<EOF > my_panda_run_script
#!/bin/bash

# Ensure SLURM_PROCID is available per task
echo "Task started: pilot_\${SLURM_PROCID} on $(hostname)"

pwd
ls

# echo $cmd
$cmd

EOF

chmod +x my_panda_run_script

echo "my_panda_run_script:"
cat my_panda_run_script

echo "LSST_LOCAL_PROLOG: ${LSST_LOCAL_PROLOG}"

if [[ -n "${LSST_LOCAL_PROLOG}" && -f "${LSST_LOCAL_PROLOG}" ]]; then
    echo "cat LSST_LOCAL_PROLOG:"
    cat "${LSST_LOCAL_PROLOG}"
    # source ${LSST_LOCAL_PROLOG}
    echo "end LSST_LOCAL_PROLOG"
else
    echo "LSST_LOCAL_PROLOG is not set or file does not exist"
fi

# using container
# IMAGE=/cvmfs/sw.lsst.eu/containers/apptainer/x86_64/almalinux/lsst_distrib/w_2026_28
IMAGE=/cvmfs/singularity.opensciencegrid.org/opensciencegrid/osgvo-el9:latest

BIND_OPTS=(
    --bind /cvmfs
    --bind /tmp
    --bind "$HOME":"$HOME"
    --bind "$PWD":"$PWD"
)

# Bind optional filesystems if they exist
for dir in /sdf /pbs /sps /lscratch /etc/grid-security /etc/lsst /cephfs /pool_1 /pool_2; do
    if [[ -d "$dir" ]]; then
        BIND_OPTS+=(--bind "$dir")
    fi
done

# OIDC_AUTH_DIR has called dirname
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
    /cvmfs/oasis.opensciencegrid.org/mis/apptainer/bin/apptainer
    exec
    "${BIND_OPTS[@]}"
    "${ENV_OPTS[@]}"
    --pwd "$PWD"
    "${IMAGE}"
    ./my_panda_run_script
)

echo "Running command:"
printf '%q ' "${CMD[@]}"
echo

"${CMD[@]}"
