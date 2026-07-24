#!/bin/bash -l
# SLURM batch job script built by arex
# 72:00:00
#SBATCH -t {requestWalltimeHour}:00:00
#SBATCH --no-requeue
#SBATCH --export=NONE
#SBATCH -e {accessPoint}/{workerID}.err
#SBATCH -o {accessPoint}/{workerID}.out

#SBATCH -p rubin
#SBATCH --nice=50
#SBATCH -J '{localQueueName}'
#SBATCH --get-user-env=10L
#SBATCH --ntasks={nCoreTotal}
#SBATCH --ntasks-per-node={nCoreTotal}
#SBATCH
#SBATCH --mem-per-cpu={requestRamPerCore}
#SBATCH --account=rubin:production --partition=milano

### partition=milano,roma

# set harvester id
export PANDA_JSID=harvester-{harvesterID}
export HARVESTER_ID={harvesterID}
export HARVESTER_WORKER_ID={workerID}

# Override umask of execution node (sometimes values are really strange)
umask 077

# export HARVESTER_WORKDIR=/sdf/home/l/lsstsvc1/harvester_workdir
# export PANDA_AUTH_DIR=/sdf/home/l/lsstsvc1/harvester_workdir/auth_tokens
# export PANDA_AUTH_TOKEN=48975ff1c8b067b9dcea54d5cdd28cc8

export PANDA_AUTH_DIR={tokenDir}
export PANDA_AUTH_TOKEN={tokenName}
export PANDA_AUTH_ORIGIN={tokenOrigin}

# export X509_USER_PROXY=/sdf/home/l/lsstsvc1/harvester/k8s/etc/certs/pilot_proxy_pilot
# latest=$(ls -td /cvmfs/sw.lsst.eu/linux-x86_64/panda_env/v* | head -1)
# rucio_cfg=${latest}/rucio/rucio-rubin.cfg
# export RUCIO_CONFIG=$rucio_cfg
# rubin_wrapper=${latest}/pilot/wrapper/rubin-wrapper.sh

latest=$(ls -td /cvmfs/sw.lsst.eu/almalinux-x86_64/panda_env/v* | head -1)
rubin_wrapper=${latest}/pilot/wrapper/rubin-wrapper.sh
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

piloturl=""
local_pilot=/sdf/data/rubin/panda_jobs/panda_env_pilot/prod_pilot3.tar.gz
if [[ -f ${local_pilot} ]]; then
    piloturl="--piloturl file://${local_pilot}"
fi

# export
# change current working directory to make sure job info file can be found in push mode
cd {accessPoint}

# ntasks={nCoreTotal}
# for i in $(seq 1 $ntasks); do
#
#    # srun --export=ALL --ntasks=1 --cpus-per-task=1 --mem-per-cpu={requestRamPerCore} /sdf/data/rubin/panda_jobs/panda_env_pilot/rubin-wrapper.sh  -s {computingSite} -r {computingSite} -q {pandaQueueName} -i PR -w generic --allow-same-user false --pilot-user rubin --noproxyverification --url https://usdf-panda-server.slac.stanford.edu:8443 -d --harvester-submit-mode {submitMode} --queuedata-url https://usdf-panda-server.slac.stanford.edu:8443/cache/schedconfig/{computingSite}.all.json --storagedata-url /sdf/home/l/lsstsvc1/cric/cric_ddmendpoints.json --use-realtime-logging --realtime-logging-server google-cloud-logging --realtime-logname Panda-RubinLog --pilotversion 3  --pythonversion 3 --localpy  | sed -e "s/^/pilot_$i: /"  &
#
#    # srun --export=ALL --ntasks=1 --cpus-per-task=1 --mem-per-cpu={requestRamPerCore} ${rubin_wrapper}  -s {computingSite} -r {computingSite} -q {pandaQueueName} -i PR -w generic --allow-same-user false --pilot-user rubin --noproxyverification --url https://usdf-panda-server.slac.stanford.edu:8443 -d --harvester-submit-mode {submitMode} --queuedata-url https://usdf-panda-server.slac.stanford.edu:8443/cache/schedconfig/{computingSite}.all.json --storagedata-url /sdf/home/l/lsstsvc1/cric/cric_ddmendpoints.json --use-realtime-logging --realtime-logging-server google-cloud-logging --realtime-logname Panda-RubinLog --pilotversion 3  --pythonversion 3 --localpy  | sed -e "s/^/pilot_$i: /"  &
#
#    srun --export=ALL --ntasks=1 --cpus-per-task=1 --mem-per-cpu={requestRamPerCore} ${rubin_wrapper}  -s {computingSite} -r {computingSite} -q {pandaQueueName} -i PR {pilotResourceTypeOption} -w generic --allow-same-user false --pilot-user rubin --es-executor-type fineGrainedProc --noproxyverification --url https://usdf-panda-server.slac.stanford.edu:8443 --harvester-submit-mode {submitMode} --queuedata-url https://usdf-panda-server.slac.stanford.edu:8443/cache/schedconfig/{computingSite}.all.json --storagedata-url /sdf/home/l/lsstsvc1/cric/cric_ddmendpoints.json --use-realtime-logging --realtime-logging-server "logserver='google-cloud-logging;https://google:80'" --realtime-logname Panda-RubinLog --pilotversion 3  --pythonversion 3 --localpy  | sed -e "s/^/pilot_$i: /"  &
#
# done
#
# wait

cat <<EOF > my_panda_run_script
#!/bin/bash

echo ${rubin_wrapper} ${piloturl} -s {computingSite} -r {computingSite} -q {pandaQueueName} -i PR {pilotResourceTypeOption} -w generic --allow-same-user false --pilot-user rubin --es-executor-type fineGrainedProc --noproxyverification --url https://usdf-panda-server.slac.stanford.edu:8443 --harvester-submit-mode {submitMode} --queuedata-url https://usdf-panda-server.slac.stanford.edu:8443/cache/schedconfig/{computingSite}.all.json --storagedata-url /sdf/home/l/lsstsvc1/cric/cric_ddmendpoints.json --use-realtime-logging --realtime-logging-server "logserver='google-cloud-logging;https://google:80'" --realtime-logname Panda-RubinLog --pilotversion 3  --pythonversion 3 --localpy  | sed -e "s/^/pilot_\${SLURM_PROCID}: /"

echo

${rubin_wrapper} ${piloturl} -s {computingSite} -r {computingSite} -q {pandaQueueName} -i PR {pilotResourceTypeOption} -w generic --allow-same-user false --pilot-user rubin --es-executor-type fineGrainedProc --noproxyverification --url https://usdf-panda-server.slac.stanford.edu:8443 --harvester-submit-mode {submitMode} --queuedata-url https://usdf-panda-server.slac.stanford.edu:8443/cache/schedconfig/{computingSite}.all.json --storagedata-url /sdf/home/l/lsstsvc1/cric/cric_ddmendpoints.json --use-realtime-logging --realtime-logging-server "logserver='google-cloud-logging;https://google:80'" --realtime-logname Panda-RubinLog --pilotversion 3  --pythonversion 3 --localpy  | sed -e "s/^/pilot_\${SLURM_PROCID}: /"

EOF

chmod +x my_panda_run_script


echo srun --export=ALL --cpus-per-task=1 --mem-per-cpu={requestRamPerCore} --ntasks={nCoreTotal} --cpu-bind=none ./my_panda_run_script
echo

srun --export=ALL --cpus-per-task=1 --mem-per-cpu={requestRamPerCore} --ntasks={nCoreTotal} --cpu-bind=none ./my_panda_run_script
