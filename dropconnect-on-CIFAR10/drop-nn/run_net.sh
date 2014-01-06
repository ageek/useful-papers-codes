#!/bin/bash

# training definitions
FILE_NAME=model_fc128-dcf
DATA_SET_PATH=/misc/vlgscratch1/FergusGroup/wan/cifar-10-py-colmajor
NN_ROOT=/misc/vlgscratch1/FergusGroup/wan/dropnn
MODEL_SCRIPT_PATH=./
NN_DEF=layers-fc128-dcf.cfg
NN_PARAMS=params-fc-11pct.cfg
MODEL_DIR=.
ADP_DROP=0
RESET_MOM=0
DATA_PROVIDER=cifar-cropped
#DATA_PROVIDER=cifar-cropped-rand

# input params
INIT_SCALE=$2
GPU=$1


# drop mode:
# 0: no drop out, general less epoch of training
# 1: drop output
# 2: drop connection, dec mini 
DROP_MODE=1

# exec file
#EXEC_CMD=python
EXEC_CMD=echo


#---------------------------------------
# dependent variables
#---------------------------------------
LOG_FILE_NAME=$MODEL_DIR/${FILE_NAME}_log.txt

# set epoch
if [ $DROP_MODE -eq 0 ]
then
    EPOCH_1=350
    EPOCH_2=150
    EPOCH_3=50
    EPOCH_4=50
else  
    EPOCH_1=700
    EPOCH_2=300
    # Experiment F-Table Dec17 and its analysis suggest 
    # epoch 3,4 should be 100,100 rather than 20,20
    # which is just double of non-drop nn
    EPOCH_3=100 
    EPOCH_4=100
fi

# set mini-batch
if [ $DROP_MODE -eq 2 ]
then
    MINI_1=64
    MINI_2=64
    MINI_3=32
    MINI_4=16
else
    MINI_1=128
    MINI_2=128
    MINI_3=128
    MINI_4=128
fi

# scale mode:
SCALE_1=$(echo $INIT_SCALE 1    | awk '{printf "%4.3f",$1*$2}' )
SCALE_2=$(echo $INIT_SCALE 1    | awk '{printf "%4.3f",$1*$2}' )
SCALE_3=$(echo $INIT_SCALE 0.1  | awk '{printf "%4.3f",$1*$2}' )
SCALE_4=$(echo $INIT_SCALE 0.01 | awk '{printf "%4.3f",$1*$2}' )

# print summary information
echo 
echo '----------------------------------------'
echo 'log file : ' ${LOG_FILE_NAME} 
echo 'epoch    : ' $EPOCH_1 $EPOCH_2 $EPOCH_3 $EPOCH_4
echo 'mini     : ' $MINI_1 $MINI_2 $MINI_3 $MINI_4
echo 'scale    : ' $SCALE_1 $SCALE_2 $SCALE_3 $SCALE_4
echo 'reset-mom : ' $RESET_MOM '   GPU      : ' ${GPU}
echo '----------------------------------------'
echo

#---------------------------------------
# run network
#---------------------------------------
# stage 1: train ranage 1-4 test on 5
EPOCH=$EPOCH_1
$EXEC_CMD $NN_ROOT/convnet.py \
   --data-path=$DATA_SET_PATH \
   --save-path=$MODEL_DIR \
   --model-file=$FILE_NAME \
   --test-range=5 --train-range=1-4 \
   --layer-def=$MODEL_SCRIPT_PATH/$NN_DEF  \
   --layer-params=$MODEL_SCRIPT_PATH/$NN_PARAMS \
   --data-provider=${DATA_PROVIDER} --test-freq=20 \
   --crop-border=4 --epoch=$EPOCH --adp-drop=$ADP_DROP \
   --gpu=$GPU --mini=$MINI_1\
   --scale=$SCALE_1 > $LOG_FILE_NAME

# stage 2: fold 5th batch 
EPOCH=`expr $EPOCH + $EPOCH_2`
$EXEC_CMD $NN_ROOT/convnet.py -f $MODEL_DIR/$FILE_NAME  \
   --train-range=1-5 --epoch=$EPOCH\
   --adp-drop=0 --mini=$MINI_2\
   --scale=$SCALE_2 >> $LOG_FILE_NAME

if [ $RESET_MOM -eq 1 ] 
then
    EPOCH=`expr $EPOCH + $EPOCH_2`
    $EXEC_CMD $NN_ROOT/convnet.py -f $MODEL_DIR/$FILE_NAME  \
        --train-range=1-5 --epoch=$EPOCH\
        --adp-drop=0 --mini=$MINI_2\
        --reset-mom=$RESET_MOM \
        --scale=$SCALE_2 >> $LOG_FILE_NAME
fi

# stage 3: dec learning rate by 10 and 20 iterations more
EPOCH=`expr $EPOCH + $EPOCH_3`
$EXEC_CMD $NN_ROOT/convnet.py -f $MODEL_DIR/$FILE_NAME  \
   --epoch=$EPOCH \
   --adp-drop=0 --mini=$MINI_3\
   --test-range=6 \
   --reset-mom=$RESET_MOM \
   --scale=$SCALE_3 >> $LOG_FILE_NAME

# stage 4: dec learning rate by 10 and 20 iterations more
EPOCH=`expr $EPOCH + $EPOCH_4`
$EXEC_CMD $NN_ROOT/convnet.py -f $MODEL_DIR/$FILE_NAME  \
   --epoch=$EPOCH \
   --adp-drop=0 --mini=$MINI_4\
   --reset-mom=$RESET_MOM \
   --multiview-test=1 \
   --logreg-name=logprob --test-range=6 \
   --scale=$SCALE_4 >> $LOG_FILE_NAME

# stage 5: test on batch 6
$EXEC_CMD $NN_ROOT/convnet.py -f $MODEL_DIR/$FILE_NAME  \
   --multiview-test=1 --test-only=1 \
   --logreg-name=logprob --test-range=6 \
   --reset-mom=$RESET_MOM >> $LOG_FILE_NAME
