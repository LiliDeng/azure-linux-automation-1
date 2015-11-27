#!/usr/bin/python

from azuremodules import *

def RunTest(command):
    UpdateState("TestRunning")
    RunLog.info("Checking resource disc...")
    osdisk = GetOSDisk()
    if (IsUbuntu()) :
        mntresource = "/dev/sdb1 on /mnt"
    elif (IsFreeBSD()):
        mntresource = "/dev/da1s1 on /mnt/resource"
    elif (osdisk == 'sdb') :
        mntresource = "/dev/sda1 on /mnt/resource"
    else :
        mntresource = "/dev/sdb1 on /mnt/resource"
    temp = Run(command)
    timeout = 0
    output = temp
    if (mntresource in output) :
        RunLog.info('Resource disk is mounted successfully.')
        if ("ext4" in output) :
            RunLog.info('Resource disk is mounted as ext4')
        elif ("ext3" in output) :
            RunLog.info('Resource disk is mounted as ext3')
        elif ("ufs" in output) :
            RunLog.info('Resource disk is mounted as ufs')
        elif ("zfs" in output) :
            RunLog.info('Resource disk is mounted as zfs')
        else :
            RunLog.info('Unknown filesystem detected for resource disk')
            ResultLog.info("FAIL")
        ResultLog.info('PASS')
        UpdateState("TestCompleted")
    else :
        RunLog.error('Resource Disk mount check failed. Mount out put is: %s', output)
        ResultLog.error('FAIL')
        UpdateState("TestCompleted")

RunTest("mount")
