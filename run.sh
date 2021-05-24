#!/bin/bash 
LINUX_DIR="/share"
FULL_VERSION=$(head $LINUX_DIR/.config | grep Kernel)
KERNEL_VERSIONS=${FULL_VERSION:12:3}

ROUND="$ROUND"
##########  need to modified! ################


RT_WORKDIR="/eva/eva/rt"
SYZ_WORKDIR="/eva/eva/syz"
MS_WORKDIR="/eva/eva/ms"
CUR_DIR="/eva/eva"
IMG_DIR="/eva/eva/image"

######################################

FUZZ_TIME="1S"

copy_kernel(){
    VERSION=$1 
    DEST=$2
    cp $IMG_DIR/stre* $DEST
    cp $LINUX_DIR/vmlinux $DEST/vmlinux
    cp $LINUX_DIR/bzImage $DEST/bzImage
}

mv_stats(){
    FROM=$1
    TO=$2
    mkdir -p $TO
    mv $FROM/corpus.db $TO/
    mv $FROM/bench.json $TO/
    mv $FROM/log $TO/
    mv $FROM/crashes $TO

} 

clean(){
    DIR=$1
    rm -rf $1/crashes
    rm -rf $1/bench.json $1/log $1/corpus.db $1/instance*
}

clean $SYZ_WORKDIR
clean $RT_WORKDIR
clean $MS_WORKDIR
sudo pkill syz-manager 
sudo pkill syz-manager  # kill twice 
sudo pkill qemu
sudo pkill qemu

for VERSION in $KERNEL_VERSIONS
do
    echo FUZZING $VERSION
    echo Copying into syzkaller
    copy_kernel $VERSION $SYZ_WORKDIR
    echo Copying into rtkaller
    copy_kernel $VERSION $RT_WORKDIR
    echo Copying into moonshine
    copy_kernel $VERSION $MS_WORKDIR 
    
        echo -e "\tROUND-$ROUND"
	
	cd $SYZ_WORKDIR
	echo -e "\t\t[+]STARTING syz"
	SYZ_RES_DIR=$LINUX_DIR/report/$VERSION/syz/Round-$ROUND
	mkdir -p $SYZ_RES_DIR
	sudo $SYZ_WORKDIR/bin/syz-manager -config config.json -bench  $SYZ_RES_DIR/bench.json > $SYZ_RES_DIR/log 2>&1 &
	sleep 1s

	cd $RT_WORKDIR
	echo -e "\t\t[+]STARTING rt"
	RT_RES_DIR=$LINUX_DIR/report/$VERSION/rt/Round-$ROUND
	mkdir -p $RT_RES_DIR
	sudo $RT_WORKDIR/bin/syz-manager -config config.json -bench $RT_RES_DIR/bench.json > $RT_RES_DIR/log 2>&1 &
	sleep 1s 

	cd $MS_WORKDIR
	echo -e "\t\t[+]STARTING ms"
	cp $CUR_DIR/corpus.db $MS_WORKDIR
	MS_RES_DIR=$LINUX_DIR/report/$VERSION/ms/Round-$ROUND
	mkdir -p $MS_RES_DIR
	sudo $MS_WORKDIR/bin/syz-manager -config config.json -bench $MS_RES_DIR/bench.json > $MS_RES_DIR/log 2>&1 &
	sleep 1s 

	echo -e "\t\t[+]ALL STARTED, waiting for $FUZZ_TIME"
        sleep $FUZZ_TIME

        sudo pkill syz-manager 
        sudo pkill syz-manager  # kill twice 
        sudo pkill qemu
        sudo pkill qemu
        echo -e "\t\t[+]FUZZ-$ROUND FINISHED"
        
	cd $CUR_DIR
	SYZ_STATS_DIR=$CUR_DIR/stats/syz/$VERSION/Round-$ROUND
	RT_STATS_DIR=$CUR_DIR/stats/rt/$VERSION/Round-$ROUND
	MS_STATS_DIR=$CUR_DIR/stats/ms/$VERSION/Round-$ROUND
	mv_stats $SYZ_WORKDIR $SYZ_STATS_DIR
	mv_stats $RT_WORKDIR $RT_STATS_DIR
	mv_stats $MS_WORKDIR $MS_STATS_DIR
#	docker run -it -v $HOST_DIR:/linux fuzzer /bin/bash
	cp -r $CUR_DIR/stats $LINUX_DIR
	echo -e "\t\t[=]STATS-$ROUND moved"
done

