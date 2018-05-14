#!/bin/bash
#
# bsd_fio.sh
#
# Description:
#    This script test the detection of a disk inside the Linux VM by performing the following steps:
#       1. Make sure the device file was created
#       2. fdisk the device
#       3. newfs the device
#       4. Mount the device
#####################################################################

ICA_TESTRUNNING="TestRunning"
ICA_TESTCOMPLETED="TestCompleted"
ICA_TESTABORTED="TestAborted"
ICA_TESTFAILED="TestFailed"

LogMsg()
{
    echo `date "+%a %b %d %T %Y"` : ${1}    # To add the timestamp to the log file
}


UpdateTestState()
{
    echo $1 > $HOME/state.txt
}

UpdateTestState $ICA_TESTRUNNING

touch $HOME/summary.log

echo Guest Distro: `uname -r` >> summary.log
date >>  summary.log
uname -a >>  summary.log

sum=`ls /dev/da* | wc -l`
if [$sum -gt 10 ]; then
    kldload geom_stripe
    gstripe label -v st0 /dev/da2 /dev/da3 /dev/da4 /dev/da5 /dev/da6 /dev/da7 /dev/da8 /dev/da9 /dev/da10 /dev/da11 /dev/da12 /dev/da13
	device="/dev/stripe/st0"
else
    device="/dev/da2"
fi


# gpart create -s GPT $device
# if [ $? -ne 0 ]; then
	# LogMsg "Error: Unable to create GPT on $device"
	# echo "Error: Unable to create GPT on $device" >> ~/summary.log
	# echo "Maybe the device $device doesn't exist, so check the /dev/ via 'ls /dev/da* /dev/ad*' command and its results are:  " >> ~/summary.log
	# ls /dev/da*  /dev/ad* >> ~/summary.log
	# UpdateTestState $ICA_TESTFAILED
	# exit 40
# fi

# gpart add -t freebsd-ufs $device
# if [ $? -ne 0 ]; then
	# LogMsg "Error: Unable to add freebsd-ufs slice to ${TEST_DEVICE}"
	# echo "Error: gpart add -t freebsd-ufs ${device} failed" >> ~/summary.log
	# UpdateTestState $ICA_TESTFAILED
	# exit 50
# fi

# newfs ${device}p1
# if [ $? -ne 0 ]; then
	# LogMsg "Error: Unable to format the device ${device}p1"
	# echo "Error: Unable to format the device ${device}p1" >> ~/summary.log
	# UpdateTestState $ICA_TESTFAILED
	# exit 60
# fi


#If we are here test executed successfully
UpdateTestState $ICA_TESTCOMPLETED

exit 0

