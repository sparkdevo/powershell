<#-----------------------------------------------------------------#>
<# 功能：                                                          #>
<# 在 Azure 上创建包含两台后端虚机的 load balancer                 #>
<# 说明：                                                          #>
<# 请根据情况修改变量 prodNamePrefix、userName、sshPublicKey 和    #>
<# location 等变量的值                                             #>
<# 用法：                                                          #>
<# 直接执行脚本 .\azureloadbalancer.ps1                            #>
<#-----------------------------------------------------------------#>

#*******************************************************************#
# 定义脚本中所需的变量
#*******************************************************************#

# 资源名称的前缀
$prodNamePrefix = "Nick"
$lowerProdNamePrefix = $prodNamePrefix.ToLower()

# vm user name
$userName = "nick"
# vm user public key
$sshPublicKey = "your public key"

# resource loacation
$location = "japaneast"
# resource group name
$rgName = $prodNamePrefix + "LBGroup"
# virtual network infomation
$vnetName = $prodNamePrefix + "LBVNet"
$vnetPrefix = "10.0.0.0/16"
$subnetName = $prodNamePrefix + "LBSubNet"
$subnetPrefix = "10.0.0.0/24"
# load balancer name
$lbName = $prodNamePrefix + "LoadBalancer"

# Azure 提供给 IP 地址的域名，
# 格式为：$dnsLabelv4 + $location + cloudapp.azure.com
$dnsLabelv4 = $lowerProdNamePrefix + "lbipv4"
$dnsLabelv6 = $lowerProdNamePrefix + "lbipv6"

# 公网 IP 实例的名称
$publicIpv4Name = $prodNamePrefix + "IPv4PublicIP"
$publicIpv6Name = $prodNamePrefix + "IPv6PublicIP"

# Load Balancer Frontend 配置的名称
$frontendV4Name = "LBFrontendIPv4"
$frontendV6Name = "LBFrontendIPv6"

# Load Balancer Backend Poll 配置的名称
$backendAddressPoolV4Name = "LBBackendPoolIPv4"
$backendAddressPoolV6Name = "LBBackendPoolIPv6"

# Load Balancer Health Probe 配置的名称
$probeV4V6Name = "HealthProbeIPv4IPv6"

# Load Balancer Inbound NAT rules 配置名称的前缀
$natRule1V4Name = "NatRule-SSH-VM1"
$natRule2V4Name = "NatRule-SSH-VM2"

# Load Balancer rules 配置的名
$lbRule1V4HTTPName = "LBRuleIPv4HTTP"
$lbRule1V6HTTPName = "LBRuleIPv6HTTP"
$lbRule1V4HTTPSName = "LBRuleIPv4HTTPS"
$lbRule1V6HTTPSName = "LBRuleIPv6HTTPS"

# Availability Set 名称
$availabilitySetName = $prodNamePrefix + "LBAvailabilitySet"

# 虚拟网卡的名称
$nic1Name = $prodNamePrefix + "IPv4IPv6Nic1"
$nic2Name = $prodNamePrefix + "IPv4IPv6Nic2"

# 虚机配置
$vmSize = "Standard_B2s"
$vmVersion = "18.04-LTS"
#$userName = "nick"
$userPassword = "123456"
#$sshPublicKey = ""
$vm1Name = $prodNamePrefix + "LBVM1"
$vm2Name = $prodNamePrefix + "LBVM2"
$vm1DiskName = $prodNamePrefix + "LBVM1_OsDisk"
$vm2DiskName = $prodNamePrefix + "LBVM2_OsDisk"
$vm1ComputerHostName = $lowerProdNamePrefix + "lbvm1"
$vm2ComputerHostName = $lowerProdNamePrefix + "lbvm2"
$storageAccountTypeName = "Standard_LRS"


#*******************************************************************#
# 创建 Resource Group、虚拟网络及其虚拟子网
#*******************************************************************#

# 创建 Resource Group
New-AzureRmResourceGroup -Name $rgName -location $location

# 虚拟网络及其虚拟子网
$backendSubnet = New-AzureRmVirtualNetworkSubnetConfig `
                 -Name $subnetName `
                 -AddressPrefix $subnetPrefix
$vnet = New-AzureRmvirtualNetwork -Name $vnetName `
                                  -ResourceGroupName $rgName `
                                  -Location $location `
                                  -AddressPrefix $vnetPrefix `
                                  -Subnet $backendSubnet


#*******************************************************************#
# 创建 Load Balancer
#*******************************************************************#

# 创建 Load Balancer 的公共 IP
$publicIPv4 = New-AzureRmPublicIpAddress `
              -Name $publicIpv4Name `
              -ResourceGroupName $rgName `
			  -Location $location `
			  -AllocationMethod Static `
			  -IpAddressVersion IPv4 `
			  -DomainNameLabel $dnsLabelv4
$publicIPv6 = New-AzureRmPublicIpAddress `
              -Name $publicIpv6Name `
			  -ResourceGroupName $rgName `
			  -Location $location `
			  -AllocationMethod Dynamic `
			  -IpAddressVersion IPv6 `
			  -DomainNameLabel $dnsLabelv6

# 创建 Load Balancer 的 Frontend IP
$FEIPConfigv4 = New-AzureRmLoadBalancerFrontendIpConfig `
                -Name $frontendV4Name `
				-PublicIpAddress $publicIPv4
$FEIPConfigv6 = New-AzureRmLoadBalancerFrontendIpConfig `
                -Name $frontendV6Name `
				-PublicIpAddress $publicIPv6

# 创建 Load Balancer 的 Backend pools
$backendpoolipv4 = New-AzureRmLoadBalancerBackendAddressPoolConfig `
                   -Name $backendAddressPoolV4Name
$backendpoolipv6 = New-AzureRmLoadBalancerBackendAddressPoolConfig `
                   -Name $backendAddressPoolV6Name

# 创建 Load Balancer 的 Inbound NAT rules
$inboundNATRule1v4 = New-AzureRmLoadBalancerInboundNatRuleConfig `
                     -Name $natRule1V4Name `
					 -FrontendIpConfiguration $FEIPConfigv4 `
					 -Protocol TCP `
					 -FrontendPort 10022 `
					 -BackendPort 22
$inboundNATRule2v4 = New-AzureRmLoadBalancerInboundNatRuleConfig `
                     -Name $natRule2V4Name `
					 -FrontendIpConfiguration $FEIPConfigv4 `
					 -Protocol TCP `
					 -FrontendPort 20022 `
					 -BackendPort 22

# 创建 Load Balancer 的 Health probes
$healthProbe = New-AzureRmLoadBalancerProbeConfig -Name $probeV4V6Name `
                                                  -Protocol Tcp `
												  -Port 22 `
												  -IntervalInSeconds 15 `
												  -ProbeCount 2

# 创建 Load Balancer 的 Load balancing rules
$lbrule1v4http = New-AzureRmLoadBalancerRuleConfig `
                 -Name $lbRule1V4HTTPName `
				 -FrontendIpConfiguration $FEIPConfigv4 `
				 -BackendAddressPool $backendpoolipv4 `
				 -Probe $healthProbe `
				 -Protocol Tcp `
				 -FrontendPort 80 `
				 -BackendPort 80
$lbrule1v6http = New-AzureRmLoadBalancerRuleConfig `
                 -Name $lbRule1V6HTTPName `
				 -FrontendIpConfiguration $FEIPConfigv6 `
				 -BackendAddressPool $backendpoolipv6 `
				 -Probe $healthProbe `
				 -Protocol Tcp `
				 -FrontendPort 80 `
				 -BackendPort 80
$lbrule1v4https = New-AzureRmLoadBalancerRuleConfig `
                  -Name $lbRule1V4HTTPSName `
				  -FrontendIpConfiguration $FEIPConfigv4 `
				  -BackendAddressPool $backendpoolipv4 `
				  -Probe $healthProbe `
				  -Protocol Tcp `
				  -FrontendPort 443 `
				  -BackendPort 443
$lbrule1v6https = New-AzureRmLoadBalancerRuleConfig `
                  -Name $lbRule1V6HTTPSName `
				  -FrontendIpConfiguration $FEIPConfigv6 `
				  -BackendAddressPool $backendpoolipv6 `
				  -Probe $healthProbe `
				  -Protocol Tcp `
				  -FrontendPort 443 `
				  -BackendPort 443

# 创建 Load Balancer
$loadbalancer = New-AzureRmLoadBalancer `
                -ResourceGroupName $rgName `
				-Name $lbName `
				-Location $location `
				-FrontendIpConfiguration $FEIPConfigv4,$FEIPConfigv6 `
				-InboundNatRule $inboundNATRule2v4,$inboundNATRule1v4 `
				-BackendAddressPool $backendpoolipv4,$backendpoolipv6 `
				-Probe $healthProbe `
				-LoadBalancingRule $lbrule1v4http,$lbrule1v6http,`
				$lbrule1v4https,$lbrule1v6https


#*******************************************************************#
# 创建两个虚拟网卡
#*******************************************************************#

# 重新获得虚拟网络及其虚拟子网的实例，
# 否则创建网卡时会提示没有指定虚拟子网
$vnet = Get-AzureRmVirtualNetwork -Name $vnetName `
                                  -ResourceGroupName $rgName
$backendSubnet = Get-AzureRmVirtualNetworkSubnetConfig `
                 -Name $subnetName `
				 -VirtualNetwork $vnet

$nic1IPv4 = New-AzureRmNetworkInterfaceIpConfig `
            -Name "IPv4IPConfig" `
			-PrivateIpAddressVersion "IPv4" `
			-Subnet $backendSubnet `
			-LoadBalancerBackendAddressPool $backendpoolipv4 `
			-LoadBalancerInboundNatRule $inboundNATRule1v4
$nic1IPv6 = New-AzureRmNetworkInterfaceIpConfig `
            -Name "IPv6IPConfig" `
			-PrivateIpAddressVersion "IPv6" `
			-LoadBalancerBackendAddressPool $backendpoolipv6
$nic1 = New-AzureRmNetworkInterface `
        -Name $nic1Name `
		-IpConfiguration $nic1IPv4,$nic1IPv6 `
		-ResourceGroupName $rgName `
		-Location $location

$nic2IPv4 = New-AzureRmNetworkInterfaceIpConfig `
            -Name "IPv4IPConfig" `
			-PrivateIpAddressVersion "IPv4" `
			-Subnet $backendSubnet `
			-LoadBalancerBackendAddressPool $backendpoolipv4 `
			-LoadBalancerInboundNatRule $inboundNATRule2v4
$nic2IPv6 = New-AzureRmNetworkInterfaceIpConfig `
            -Name "IPv6IPConfig" `
			-PrivateIpAddressVersion "IPv6" `
			-LoadBalancerBackendAddressPool $backendpoolipv6
$nic2 = New-AzureRmNetworkInterface `
        -Name $nic2Name `
		-IpConfiguration $nic2IPv4,$nic2IPv6 `
		-ResourceGroupName $rgName `
		-Location $location


#*******************************************************************#
# 创建虚拟机并分配新建的 NIC
#*******************************************************************#

# 创建 Availability Set
New-AzureRmAvailabilitySet -Name $availabilitySetName `
                           -Sku Aligned `
						   -PlatformFaultDomainCount 2 `
						   -PlatformUpdateDomainCount 5 `
						   -ResourceGroupName $rgName `
						   -location $location
$availabilitySet = Get-AzureRmAvailabilitySet `
                   -Name $availabilitySetName `
				   -ResourceGroupName $rgName

# 创建用户 Credential
$securePassword = ConvertTo-SecureString $userPassword `
                                         -AsPlainText -Force
$userCred = New-Object System.Management.Automation.PSCredential `
            ($userName, $securePassword)

# 创建第一台虚机
$vm1 = New-AzureRmVMConfig -VMName $vm1Name `
                           -VMSize $vmSize `
						   -AvailabilitySetId $availabilitySet.Id
$vm1 = Set-AzureRmVMOperatingSystem `
       -VM $vm1 `
       -Linux `
	   -ComputerName $vm1ComputerHostName `
	   -Credential $userCred `
	   -DisablePasswordAuthentication
$vm1 = Set-AzureRmVMSourceImage `
       -VM $vm1 `
	   -PublisherName Canonical `
	   -Offer UbuntuServer `
	   -Skus $vmVersion `
	   -Version "latest"
$vm1 = Set-AzureRmVMBootDiagnostics `
       -VM $vm1 `
	   -Disable
$vm1 = Add-AzureRmVMNetworkInterface `
       -VM $vm1 `
	   -Id $nic1.Id `
	   -Primary
$vm1 = Set-AzureRmVMOSDisk `
       -VM $vm1 `
	   -Name $vm1DiskName `
	   -CreateOption FromImage `
	   -StorageAccountType $storageAccountTypeName
Add-AzureRmVMSshPublicKey `
    -VM $vm1 `
    -KeyData $sshPublicKey `
	-Path "/home/$userName/.ssh/authorized_keys"
New-AzureRmVM -ResourceGroupName $rgName `
              -Location $location `
			  -VM $vm1

# 创建第二台虚机
$vm2 = New-AzureRmVMConfig -VMName $vm2Name `
                           -VMSize $vmSize `
						   -AvailabilitySetId $availabilitySet.Id
$vm2 = Set-AzureRmVMOperatingSystem `
       -VM $vm2 `
	   -Linux `
	   -ComputerName $vm2ComputerHostName `
	   -Credential $userCred `
	   -DisablePasswordAuthentication
$vm2 = Set-AzureRmVMSourceImage `
       -VM $vm2 `
	   -PublisherName Canonical `
	   -Offer UbuntuServer `
	   -Skus $vmVersion `
	   -Version "latest"
$vm2 = Set-AzureRmVMBootDiagnostics `
       -VM $vm2 `
	   -Disable
$vm2 = Add-AzureRmVMNetworkInterface `
       -VM $vm2 `
	   -Id $nic2.Id `
	   -Primary
$vm2 = Set-AzureRmVMOSDisk `
       -VM $vm2 `
	   -Name $vm2DiskName `
	   -CreateOption FromImage `
	   -StorageAccountType $storageAccountTypeName
Add-AzureRmVMSshPublicKey `
    -VM $vm2 `
	-KeyData $sshPublicKey `
	-Path "/home/$userName/.ssh/authorized_keys"
New-AzureRmVM -ResourceGroupName $rgName `
              -Location $location `
			  -VM $vm2

Write-Host "The creation of Load Balancer is completed."