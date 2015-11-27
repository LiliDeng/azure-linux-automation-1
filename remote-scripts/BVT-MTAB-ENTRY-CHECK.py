#!/usr/bin/python

from azuremodules import *

def RunTest(command):
    if (IsFreeBSD()):
        RunLog.info("Checking for resource disk entry from mount output on FreeBSD.")
    else:
        RunLog.info("Checking for resource disk entry in /etc/mtab.")
    output = Run(command)
    if (IsUbuntu()) :
        mntresource1 = "/dev/sdb1 /mnt"
        mntresource2 = "/dev/sda1 /mnt"
    elif (IsFreeBSD()):
            mntresource1 = "/dev/da1s1 on /mnt/resource"
            mntresource2 = "/dev/da2s1 on /mnt/resource"
    else :
        mntresource1 = "/dev/sdb1 /mnt/resource"
        # There's rare cases that the resource disk is the first disk, it's acceptable as device names are not persistent on Linux
        mntresource2 = "/dev/sda1 /mnt/resource"

    if (mntresource1 in output) or (mntresource2 in output) :
        RunLog.info('Resource disk entry is present.')
        ResultLog.info('PASS')
        str_out = output.splitlines()
        #len_out = len(str_out)
        for each in str_out :
            #print(each)
            if (mntresource1 in each) or (mntresource2 in each) :
                RunLog.info("%s", each)

        UpdateState("TestCompleted")

    else :
        RunLog.error('Resource disk entry is not present.')
        ResultLog.error('FAIL')
        UpdateState("TestCompleted")

if (IsFreeBSD()):
    RunTest("mount")
else:
    RunTest("cat /etc/mtab")