#!/bin/zsh

# See also https://www.rocker-project.org/use/singularity/
RSTUDIO_VERSION=${1}
if [ -z $RSTUDIO_VERSION ]; then
    RSTUDIO_VERSION="latest"
fi

printf "Using Rstudio ${RSTUDIO_VERSION}\n"

# Main parameters for the script with default values
IP=$(/sbin/ip route get 8.8.8.8 | awk '{print $(NF-2);exit}')
PORT=${PORT:-1313}
printf "Open link:\nhttp://%s:%s\n\n" $IP $PORT
printf "Or forward:\nssh -fNL 1313:%s:%s zm104@eris2n5.research.partners.org\n\n" $HOSTNAME $PORT
printf "Or use this in VS Code: %s:%s\n\n" $HOSTNAME $PORT

USER=$(whoami)
PASSWORD=123456
TMPDIR="/PHShome/zm104/scratch/tmp"
CONTAINER="/PHShome/zm104/tools/rstudio-server-conda/singularity/rstudio_${RSTUDIO_VERSION}.sif"
R_BIN=/PHShome/zm104/miniforge3/envs/R43/bin/R

workdir=$(python -c 'import tempfile; print(tempfile.mkdtemp())')

mkdir -p -m 700 ${workdir}/run ${workdir}/tmp ${workdir}/var/lib/rstudio-server
cat > ${workdir}/database.conf <<END
provider=sqlite
directory=/var/lib/rstudio-server
END

# Set OMP_NUM_THREADS to prevent OpenBLAS (and any other OpenMP-enhanced
# libraries used by R) from spawning more threads than the number of processors
# allocated to the job.
#
# Set R_LIBS_USER to a path specific to rocker/rstudio to avoid conflicts with
# personal libraries from any R installation in the host environment

cat > ${workdir}/rsession.sh <<END
#!/bin/sh
export OMP_NUM_THREADS=${SLURM_JOB_CPUS_PER_NODE}
export R_LIBS_USER=${HOME}/R/rocker-rstudio/4.2
exec /usr/lib/rstudio-server/bin/rsession "\${@}"
END

chmod +x ${workdir}/rsession.sh

export SINGULARITY_BIND="${workdir}/run:/run,${workdir}/tmp:/tmp,${workdir}/database.conf:/etc/rstudio/database.conf,${workdir}/rsession.sh:/etc/rstudio/rsession.sh,${workdir}/var/lib/rstudio-server:/var/lib/rstudio-server"

# Do not suspend idle sessions.
# Alternative to setting session-timeout-minutes=0 in /etc/rstudio/rsession.conf
# https://github.com/rstudio/rstudio/blob/v1.4.1106/src/cpp/server/ServerSessionManager.cpp#L126
export SINGULARITYENV_RSTUDIO_SESSION_TIMEOUT=0

export SINGULARITYENV_USER=${USER}
export SINGULARITYENV_PASSWORD=123456
# get unused socket per https://unix.stackexchange.com/a/132524
# tiny race condition between the python & singularity commands
readonly PORT=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')

apptainer exec \
    --cleanenv --network=none \
    --bind ${CONDA_PREFIX}:${CONDA_PREFIX} \
    --bind /data/srlab2:/data/srlab2 \
    --bind /PHShome/zm104/tools:/PHShome/zm104/tools \
    --env CONDA_PREFIX=${CONDA_PREFIX} \
    --env RSTUDIO_WHICH_R=${R_BIN} \
    --env RETICULATE_PYTHON=${PY_BIN} \
    --env PASSWORD=${PASSWORD} \
    --env PORT=${PORT} \
    --env USER=${USER} \
    ${CONTAINER} /usr/lib/rstudio-server/bin/rserver \
        --rsession-which-r=${RSTUDIO_WHICH_R} \
        --rsession-path=/etc/rstudio/rsession.sh \
        --rsession-ld-library-path=${CONDA_PREFIX}/lib \
        --www-address=${IP} \
        --www-port=${PORT} \
        --server-user=${USER} \
        --auth-none=0 \
        --auth-pam-helper-path=pam-helper \
        --auth-timeout-minutes=0 \
        --auth-stay-signed-in-days=30

printf 'rserver exited' 1>&2
