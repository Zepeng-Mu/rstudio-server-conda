#!/bin/zsh

# See also https://www.rocker-project.org/use/singularity/
RSTUDIO_VERSION=${1}
if [ -z $RSTUDIO_VERSION ]; then
    RSTUDIO_VERSION="4.2.0"
fi

printf "Using Rstudio ${RSTUDIO_VERSION}\n"

# Main parameters for the script with default values
IP=$(/sbin/ip route get 8.8.8.8 | awk '{print $(NF-2);exit}')
PORT=${PORT:-1313}
printf "Open link:\nhttp://%s:%s\n\n" $IP $PORT
printf "Or forward:\nssh -fNL 1313:%s:%s zepengmu@midway3-login3.rcc.uchicago.edu\n\n" $HOSTNAME $PORT
printf "Or use this in VS Code: %s:%s\n\n" $HOSTNAME $PORT

USER=$(whoami)
PASSWORD=567890
TMPDIR=/scratch/midway3/zepengmu/tmp
CONTAINER="/scratch/midway3/zepengmu/rstudio-server-conda/singularity/rstudio_${RSTUDIO_VERSION}.sif"

# Set-up temporary paths
RSTUDIO_TMP="${TMPDIR}/$(echo -n $CONDA_PREFIX | md5sum | awk '{print $1}')"
mkdir -p $RSTUDIO_TMP/{run,var-lib-rstudio-server,local-share-rstudio,tmp}

R_BIN=$CONDA_PREFIX/bin/R
PY_BIN=$CONDA_PREFIX/bin/python

if [ ! -f $CONTAINER ]; then
    singularity build --fakeroot $CONTAINER Singularity
fi

if [ -z "$CONDA_PREFIX" ]; then
    echo "Activate a conda env or specify \$CONDA_PREFIX"
    exit 1
fi

export SINGULARITY_CACHEDIR=/scratch/midway3/zepengmu/.singularity
export XDG_DATA_HOME=/scratch/midway3/zepengmu/.local/share

/software/singularity-3.9.2-el8-x86_64/bin/singularity exec \
    --bind $RSTUDIO_TMP/run:/run \
    --bind $RSTUDIO_TMP/tmp:/tmp \
    --bind /scratch/midway3/zepengmu/rstudio-server-conda/singularity/database.conf:/etc/rstudio/database.conf \
    --bind /scratch/midway3/zepengmu/rstudio-server-conda/singularity/rsession.conf:/etc/rstudio/rsession.conf \
    --bind /scratch/midway3/zepengmu/rstudio-server-conda/singularity/rserver.conf:/etc/rstudio/rserver.conf \
    --bind $RSTUDIO_TMP/var-lib-rstudio-server:/var/lib/rstudio-server \
    --bind /sys/fs/cgroup/:/sys/fs/cgroup/:ro \
    --bind $RSTUDIO_TMP/local-share-rstudio:/home/rstudio/.local/share/rstudio \
    --bind ${CONDA_PREFIX}:${CONDA_PREFIX} \
    --bind $HOME/.config/rstudio:/home/rstudio/.config/rstudio \
    --bind /project:/project \
    --bind /project2:/project2 \
    --bind /scratch/midway3/zepengmu:/scratch/midway3/zepengmu \
    --env CONDA_PREFIX=$CONDA_PREFIX \
    --env RSTUDIO_WHICH_R=$R_BIN \
    --env RETICULATE_PYTHON=$PY_BIN \
    --env PASSWORD=$PASSWORD \
    --env PORT=$PORT \
    --env USER=$USER \
    ${CONTAINER} rserver \
    --rsession-which-r=${R_BIN} \
    --rsession-ld-library-path=${CONDA_PREFIX}/lib \
    --www-address=${IP} \
    --www-port=${PORT} \
    --server-user=${USER} \
    --auth-none=0 \
    --auth-pam-helper-path=pam-helper \
    --auth-timeout-minutes=300 \
    --auth-stay-signed-in-days=3
