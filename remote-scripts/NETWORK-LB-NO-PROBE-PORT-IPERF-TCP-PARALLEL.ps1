﻿Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if ($isDeployed)
{
	$vm1added = $false
	foreach ($VMdata in $allVMData)
	{
		if ($VMdata.RoleName -imatch $currentTestData.setupType )
		{
			if ( $vm1added )
			{
				$hs1VIP = $VMdata.PublicIP
				$hs1vm2sshport = $VMdata.SSHPort
				$hs1vm2tcpport = $VMdata.TCPtestPort
				$hs1ServiceUrl = $VMdata.URL
			}
			else
			{
				$hs1VIP = $VMdata.PublicIP
				$hs1vm1sshport = $VMdata.SSHPort
				$hs1vm1tcpport = $VMdata.TCPtestPort
				$hs1ServiceUrl = $VMdata.URL
				$vm1added = $true
			}
		}
		elseif ($VMdata.RoleName -imatch "DTAP")
		{
			$dtapServerIp = $VMdata.PublicIP
			$dtapServerSshport = $VMdata.SSHPort
			$dtapServerTcpport = $VMdata.TCPtestPort
		}
	}	
	LogMsg "Test Machine 1 : $hs1VIP : $hs1vm1sshport"
	LogMsg "Test Machine 2 : $hs1VIP : $hs1vm2sshport"
	LogMsg "DTAP Machine : $dtapServerIp : $hs1vm1sshport"
	$iperfTimeoutSeconds = $currentTestData.iperfTimeoutSeconds

	$wait=30
	$cmd1="$python_cmd start-server.py -p $hs1vm1tcpport && mv -f Runtime.log start-server.py.log"
	$cmd2="$python_cmd start-server.py -p $hs1vm2tcpport && mv -f Runtime.log start-server.py.log"

	$server1 = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -nodeTcpPort $hs1vm1tcpport -nodeIperfCmd $cmd1 -user $user -password $password -files $currentTestData.files -logDir $LogDir -nodeDip $hs1vm1.IpAddress
	$server2 = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm2sshport -nodeTcpPort $hs1vm2tcpport -nodeIperfCmd $cmd2 -user $user -password $password -files $currentTestData.files -logDir $LogDir -nodeDip $hs1vm2.IpAddress
	$client = CreateIperfNode -nodeIp $dtapServerIp -nodeSshPort $dtapServerSshport -nodeTcpPort $dtapServerTcpport -nodeIperfCmd $cmd3 -user $user -password $password -files $currentTestData.files -logDir $LogDir
	$resultArr = @()
	$result = "", ""


	foreach ($Value in $currentTestData.SubtestValues.Split(","))  
	{
		mkdir $LogDir\$Value -ErrorAction SilentlyContinue | out-null
		foreach ($mode in $currentTestData.TestMode.Split(","))
		{
			mkdir $LogDir\$Value\$mode -ErrorAction SilentlyContinue | out-null
			try
			{
				$testResult = $null
				LogMsg "Starting test for $Value parallel connections in $mode mode.."
				if(($mode -eq "IP") -or ($mode -eq "VIP") -or ($mode -eq "DIP"))
				{#.........................................................................Client command will decided according to TestMode....
					$cmd3="$python_cmd start-client.py -c $hs1VIP -p $hs1vm1tcpport -t$iperfTimeoutSeconds -P$Value" 
				}
				if(($mode -eq "URL") -or ($mode -eq "Hostname"))
				{
					$cmd3="$python_cmd start-client.py -c $hs1ServiceUrl -p $hs1vm1tcpport -t$iperfTimeoutSeconds -P$Value"
				}
				$client.cmd = $cmd3
				mkdir $LogDir\$Value\$mode\Server1 -ErrorAction SilentlyContinue | out-null
				mkdir $LogDir\$Value\$mode\Server2 -ErrorAction SilentlyContinue | out-null
				$server1.logDir = "$LogDir\$Value\$mode\Server1"
				$server2.logDir = "$LogDir\$Value\$mode\Server2"
				$client.logDir = "$LogDir\$Value\$mode"
				$client.cmd = $cmd3

				RemoteCopy -uploadTo $server1.ip -port $server1.sshPort -files $server1.files -username $server1.user -password $server1.password -upload
				RemoteCopy -uploadTo $server2.Ip -port $server2.sshPort -files $server2.files -username $server2.user -password $server2.password -upload
				RemoteCopy -uploadTo $client.Ip -port $client.sshPort -files $client.files -username $client.user -password $client.password -upload

				$suppressedOut = RunLinuxCmd -username $server2.user -password $server2.password -ip $server2.ip -port $server2.sshPort -command "chmod +x *" -runAsSudo
				$suppressedOut = RunLinuxCmd -username $server1.user -password $server1.password -ip $server1.ip -port $server1.sshPort -command "chmod +x *" -runAsSudo
				$suppressedOut = RunLinuxCmd -username $client.user -password $client.password -ip $client.ip -port $client.sshPort -command "chmod +x *" -runAsSudo

				$suppressedOut = RunLinuxCmd -username $server1.user -password $server1.password -ip $server1.ip -port $server1.sshport -command "echo Test Started > iperf-server.txt" -runAsSudo
				$suppressedOut = RunLinuxCmd -username $server2.user -password $server2.password -ip $server2.ip -port $server2.sshPort -command "echo Test Started > iperf-server.txt" -runAsSudo

				StartIperfServer $server1
				StartIperfServer $server2

				$isServer1Started = IsIperfServerStarted $server1
				$isServer2Started = IsIperfServerStarted $server2
				Sleep($wait)
				if(($isServer1Started -eq $true) -and ($isServer2Started -eq $true)) 
				{
					LogMsg "Iperf Server1 and Server2 started successfully. Listening TCP port $($client.tcpPort) ..."
#>>>On confirmation, of server starting, let's start iperf client...
					$suppressedOut = RunLinuxCmd -username $client.user -password $client.password -ip $client.ip -port $client.sshport -command "echo Test Started > iperf-client.txt" -runAsSudo
					StartIperfClient $client
					$isClientStarted = IsIperfClientStarted $client
					$suppressedOut = RunLinuxCmd -username $server1.user -password $server1.password -ip $server1.ip -port $server1.sshport -command "echo TestComplete >> iperf-server.txt" -runAsSudo
					$suppressedOut = $suppressedOut = RunLinuxCmd -username $server2.user -password $server2.password -ip $server2.ip -port $server2.sshPort -command "echo TestComplete >> iperf-server.txt" -runAsSudo
					if($isClientStarted -eq $true)
					{
						$server1State = IsIperfServerRunning $server1
						$server2State = IsIperfServerRunning $server2
						if(($server1State -eq $true) -and ($server2State -eq $true)) {
							LogMsg "Test Finished..!"
							$testResult = "PASS"
						} else {
							LogErr "Test Finished..!"
							$testResult = "FAIL"
						}
						$clientLog= $client.LogDir + "\iperf-client.txt"
						$isClientConnected = AnalyseIperfClientConnectivity -logFile $clientLog -beg "Test Started" -end "TestComplete"
						$clientConnCount = GetParallelConnectionCount -logFile $clientLog -beg "Test Started" -end "TestComplete"
						If ($isClientConnected)
						{
							$testResult = "PASS"
							$server1Log= $server1.LogDir + "\iperf-server.txt"
							$server2Log= $server2.LogDir + "\iperf-server.txt"
							$isServerConnected1 = AnalyseIperfServerConnectivity $server1Log "Test Started" "TestComplete"
							$isServerConnected2 = AnalyseIperfServerConnectivity $server2Log "Test Started" "TestComplete"
							If (($isServerConnected1) -and ($isServerConnected2)) 
							{
								$testResult = "PASS"

								$connectStr1="$($server1.DIP)\sport\s\d*\sconnected with $($client.ip)\sport\s\d"
								$connectStr2="$($server2.DIP)\sport\s\d*\sconnected with $($client.ip)\sport\s\d"

								$server1ConnCount = GetStringMatchCount -logFile $server1Log -beg "Test Started" -end "TestComplete" -str $connectStr1
								$server2ConnCount = GetStringMatchCount -logFile $server2Log -beg "Test Started" -end "TestComplete" -str $connectStr2
#Verify Custom Probe Messages on both server

								LogMsg "Server1 Parallel Connection Count is $server1ConnCount"
								LogMsg "Server2 Parallel Connection Count is $server2ConnCount"
								$diff = [Math]::Abs($server1ConnCount - $server2ConnCount)
								If ((($diff/$Value)*100) -lt 20) 
								{
									$testResult = "PASS"
									LogMsg "Connection Counts are distributed evenly in both Servers"
									LogMsg "Diff between server1 and server2 is $diff"
								} 
								else
								{
									$testResult = "FAIL"
									LogErr "Connection Counts are not distributed correctly"
									LogErr "Diff between server1 and server2 is $diff"
								}
							}	
							else 
							{
								$testResult = "FAIL"
								LogErr "Server is not Connected to Client"
							}
						} 
						else 
						{
							$testResult = "FAIL"
							LogErr "Client is not Connected to Client"
						}	
					} 
					else 
					{
						LogErr "Failured detected in client connection."
						RemoteCopy -download -downloadFrom $server1.ip -files "/home/$user/iperf-server.txt" -downloadTo $server1.LogDir -port $server1.sshPort -username $server1.user -password $server1.password
						LogMsg "Test Finished..!"
						$testResult = "FAIL"
					}
				} 
				else	
				{
					LogErr "Unable to start iperf-server. Aborting test."
					RemoteCopy -download -downloadFrom $server1.ip -files "/home/$user/iperf-server.txt" -downloadTo $server1.LogDir -port $server1.sshPort -username $server1.user -password $server1.password
					RemoteCopy -download -downloadFrom $server2.ip -files "/home/$user/iperf-server.txt" -downloadTo $server2.LogDir -port $server2.sshPort -username $server2.user -password $server2.password
					$testResult = "Aborted"
				}

				LogMsg "Test Finished for Parallel Connections $Value, result is $testResult"
			}
			catch
			{
				$ErrorMessage =  $_.Exception.Message
				LogErr "EXCEPTION : $ErrorMessage"   
			}
			Finally
			{
				$metaData = " $mode" 
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
