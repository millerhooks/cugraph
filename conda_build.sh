#!/usr/bin/env bash
set -xe

CUDA_REL=${CUDA_VERSION%.*}

conda install conda-build anaconda-client conda-verify -y
conda build -c nvidia -c rapidsai -c rapidsai-nightly/label/cuda${CUDA_REL} -c conda-forge -c defaults --python=${PYTHON} conda/recipes/cugraph

if [ "$UPLOAD_PACKAGE" == '1' ]; then
    export UPLOADFILE=`conda build -c nvidia -c rapidsai -c conda-forge -c defaults --python=${PYTHON} conda/recipes/cugraph --output`
    SOURCE_BRANCH=master

    test -e ${UPLOADFILE}


    LABEL_OPTION="--label dev --label cuda${CUDA_REL}"
    if [ "${LABEL_MAIN}" == '1' ]; then
    LABEL_OPTION="--label main --label cuda${CUDA_REL}"
    fi
    echo "LABEL_OPTION=${LABEL_OPTION}"

    if [ -z "$MY_UPLOAD_KEY" ]; then
    echo "No upload key"
    return 0
    fi

    echo "Upload"
    echo ${UPLOADFILE}
    anaconda -t ${MY_UPLOAD_KEY} upload -u ${CONDA_USERNAME:-rapidsai} ${LABEL_OPTION} --force ${UPLOADFILE}
else
    echo "Skipping upload"
fi
