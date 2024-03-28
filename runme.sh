#!/bin/bash

set -xe

HOSTS="localhost"
#WORKLOAD="unet3d"
#MODELS="resnet50 cosmoflow unet3d"
MODELS="resnet50 cosmoflow"
GPU_TYPE="h100"
GPU_NUM=8 


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

echo "Generating configurations"
./benchmark.sh datasize --workload ${WORKLOAD} --accelerator-type ${GPU_TYPE} --num-accelerators ${GPU_NUM} --num-client-hosts ${CLIENT_NUM} --client-host-memory-in-gb ${HOST_MEM_GB}

TRAIN_FILE_NUM=$( ./benchmark.sh datasize --workload ${WORKLOAD} --accelerator-type ${GPU_TYPE} --num-accelerators ${GPU_NUM} --num-client-hosts ${CLIENT_NUM} --client-host-memory-in-gb ${HOST_MEM_GB} | grep dataset.num_files_train |sed 's/.*dataset.num_files_train=\([^ ]*\).*/\1/') 
sleep 3
 
echo "Generating data files"
if [[ -d /data/${WORKLOAD}-${GPU_TYPE}-${TRAIN_FILE_NUM} ]]; then
    echo "Dataset folder /data/${WORKLOAD}-${GPU_TYPE}-${TRAIN_FILE_NUM} already exist, re-using it"
else
    echo "No exsiting dataset found, building it under /data/${WORKLOAD}-${GPU_TYPE}-${TRAIN_FILE_NUM}"
    sleep 3
    ./benchmark.sh datagen --workload ${WORKLOAD} --accelerator-type ${GPU_TYPE} --num-parallel ${WRITER} --param dataset.num_files_train=${TRAIN_FILE_NUM} --param dataset.data_folder=/data/${WORKLOAD}-${GPU_TYPE}-${TRAIN_FILE_NUM}
fi

echo "Running the test"
sleep 3
./benchmark.sh run -s ${HOSTS} --workload ${WORKLOAD} --accelerator-type ${GPU_TYPE} --num-accelerators ${GPU_NUM} --results-dir /results/${WORKLOAD}-${DATETIME} --param dataset.num_files_train=${TRAIN_FILE_NUM} --param dataset.data_folder=/data/${WORKLOAD}-${GPU_TYPE}-${TRAIN_FILE_NUM} -p reader.read_threads=${READER}


AU=$( grep "train_au_meet_expectation"  /results/${WORKLOAD}-${DATETIME}/summary.json |awk '{print $2}'| cut -d\" -f2)
if [[  "$AU" != "success" ]]
then
	echo "AU fail, please check log"
else
	
	echo "Generating the report"
	sleep 3
	./benchmark.sh reportgen --results-dir /results/${WORKLOAD}-${DATETIME}
fi

done

exit 0







