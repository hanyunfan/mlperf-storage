#!/bin/bash

set -xe

HOSTS="localhost"
#WORKLOAD="unet3d"
#MODELS="resnet50 cosmoflow unet3d"
#MODELS="unet3d"
MODELS="resnet50 cosmoflow"
GPU_TYPE="h100"
GPU_NUM=8 
#DATASET_PATH=/data
DATASET_PATH=/MLPlocal
RESULTS_DIR=/results

#Auto-file parameters
#CLIENT_NUM=1
CLIENT_NUM=$( echo $HOSTS |wc -w )
HOST_MEM_GB=128
#HOST_MEM_GB=$( ssh $( echo $HOSTS|cut -d' ' -f1 ) free -g |grep Mem| awk '{print $2}' )
CPU_CORES=$( ssh $( echo $HOSTS|cut -d' ' -f1 ) nproc --all )
WRITER=$(( $CPU_CORES / 2 ))
READER=$(( $GPU_NUM * 8 ))


DATETIME=`date +'%Y%m%d%H%M%S'`

for WORKLOAD in $MODELS
do

echo "Step 1: Generating configurations"
./benchmark.sh datasize --workload ${WORKLOAD} --accelerator-type ${GPU_TYPE} --num-accelerators ${GPU_NUM} --num-client-hosts ${CLIENT_NUM} --client-host-memory-in-gb ${HOST_MEM_GB}

TRAIN_FILE_NUM=$( ./benchmark.sh datasize --workload ${WORKLOAD} --accelerator-type ${GPU_TYPE} --num-accelerators ${GPU_NUM} --num-client-hosts ${CLIENT_NUM} --client-host-memory-in-gb ${HOST_MEM_GB} | grep dataset.num_files_train |sed 's/.*dataset.num_files_train=\([^ ]*\).*/\1/') 

sleep 3
 
echo "Step 2: Generating data files"

if [[ -d /${DATASET_PATH}/${WORKLOAD}-${GPU_TYPE}-${TRAIN_FILE_NUM} ]]; then
    echo "Dataset folder /${DATASET_PATH}/${WORKLOAD}-${GPU_TYPE}-${TRAIN_FILE_NUM} already exist, re-using it"
else
    echo "No exsiting dataset found, building it under /${DATASET_PATH}/${WORKLOAD}-${GPU_TYPE}-${TRAIN_FILE_NUM}"
    sleep 3
    ./benchmark.sh datagen -s ${HOSTS} --workload ${WORKLOAD} --accelerator-type ${GPU_TYPE} --num-parallel ${WRITER} --param dataset.num_files_train=${TRAIN_FILE_NUM} --param dataset.data_folder=/${DATASET_PATH}/${WORKLOAD}-${GPU_TYPE}-${TRAIN_FILE_NUM}
fi

echo "Step 3: Running the test"

for i in {1..5}
do
    echo "run $i of 5"
    #clear cache
    sync; echo 3 > /proc/sys/vm/drop_caches
    sleep 30

    ./benchmark.sh run -s ${HOSTS} --workload ${WORKLOAD} --accelerator-type ${GPU_TYPE} --num-accelerators ${GPU_NUM} --results-dir /${RESULTS_DIR}/${WORKLOAD}-${DATETIME}/run${i} --param dataset.num_files_train=${TRAIN_FILE_NUM} --param dataset.data_folder=/${DATASET_PATH}/${WORKLOAD}-${GPU_TYPE}-${TRAIN_FILE_NUM} -p reader.read_threads=${READER}

    if [ $? -ne 0 ]; then
        echo "Run $i of 5 of $MODELS  failed. Check dlio.log for details."
        exit 1
    else
    echo "Run $i of 5 of $MODELS completed successfully."
    fi
done

#    AU=$( grep "train_au_meet_expectation"  /${RESULTS_DIR}/${WORKLOAD}-${DATETIME}/run${i}/summary.json |awk '{print $2}'| cut -d\" -f2)
#    if [[  "$AU" != "success" ]]
#    then
#    	echo "AU fail, please check log"
#    else

done 

for WORKLOAD in $MODELS
do
    echo "Step 4: Generating the report"
    sleep 3
    #./benchmark.sh reportgen --results-dir /${RESULTS_DIR}/${WORKLOAD}-${DATETIME}/run${i} 
    ./benchmark.sh reportgen --results-dir /${RESULTS_DIR}/${WORKLOAD}-${DATETIME} 
#    fi

done



exit 0







