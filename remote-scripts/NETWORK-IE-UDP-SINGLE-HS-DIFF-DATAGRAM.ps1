﻿Import-Module .\TestLibs\RDFELibs.psm1 -Force
$Subtests= $currentTestData.SubtestValues
$SubtestValues = $Subtests.Split(",")
$resultSummary = ""
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if ($isDeployed)
{



	$hs1VIP = $allVMData[0].PublicIP
	$hs1ServiceUrl = $allVMData[0].URL
	$hs1vm1IP = $allVMData[0].InternalIP
	$hs1vm1Hostname = $allVMData[0].RoleName
	$hs1vm1sshport = $allVMData[0].SSHPort
	$hs1vm1tcpport = $allVMData[0].TCPtestPort
	$hs1vm1udpport = $allVMData[0].UDPtestPort
	
	$hs1vm2IP = $allVMData[1].InternalIP
	$hs1vm2Hostname = $allVMData[1].RoleName
	$hs1vm2sshport = $allVMData[1].SSHPort
	$hs1vm2tcpport = $allVMData[1].TCPtestPort
	$hs1vm2udpport = $allVMData[1].UDPtestPort

	$iperfTimeoutSeconds = $currentTestData.iperfTimeoutSeconds

	foreach ($Value in $SubtestValues)
	{
		foreach ($mode in $currentTestData.TestMode.Split(","))
		{   
			try
			{
				$testResult = $null
				$cmd1="$python_cmd start-server.py -p $hs1vm1udpport -u yes && mv -f Runtime.log start-server.py.log"
				if ($mode -eq "VIP")
				{
					$cmd2="$python_cmd start-client.py -c $hs1vm1IP  -p $hs1vm1udpport -t$iperfTimeoutSeconds -u yes -l $Value" 
				}
				elseif($mode -eq "URL")
				{
					$cmd2="$python_cmd start-client.py -c $hs1vm1Hostname  -p $hs1vm1udpport -t$iperfTimeoutSeconds -u yes -l $Value"
				}
				LogMsg "Starting in $mode mode.."
				$a = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -nodeUdpPort $hs1vm1udpport -nodeIperfCmd $cmd1 -user $user -password $password -files $currentTestData.files -logDir $LogDir
				$b = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm2sshport -nodeUdpPort $hs1vm2udpport -nodeIperfCmd $cmd2 -user $user -password $password -files $currentTestData.files -logDir $LogDir
				LogMsg "Test Started for UDP Datagram size $Value"
				mkdir $LogDir\$Value -ErrorAction SilentlyContinue | out-null
				mkdir $LogDir\$Value\$mode -ErrorAction SilentlyContinue | out-null

				$b.logDir = $LogDir + "\$Value\$mode"
				$a.logDir = $LogDir + "\$Value\$mode"
				$server = $a
				$client = $b
				$testResult = IperfClientServerUDPDatagramTest -server $server -client $client
				LogMsg "$($currentTestData.testName) : $Value : $mode : $testResult"
			}
			catch
			{
				$ErrorMessage =  $_.Exception.Message
				LogErr "EXCEPTION : $ErrorMessage"   
			}
			Finally
			{
				$metaData = "$Value : $mode" 
				if (!$testResult)
				{
					$testResult = "Aborted"
				}
				$resultArr += $testResult
				$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
			}   
		}
	}
}
else
{
	$testResult = "Aborted"
	$resultArr += $testResult
}
$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
return $result,$resultSummary
