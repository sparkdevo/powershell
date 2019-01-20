<#-----------------------------------------------------------------#>
<# 功能：                                                          #>
<# 为 Azure 上已经存在的 load balancer 添加第 n 台后端虚机         #>
<# 说明：                                                          #>
<# 请根据情况修改变量 vmIndex、prodNamePrefix、userName、          #>
<# sshPublicKey 和 location 等变量的值                             #>
<# 用法：                                                          #>
<# 直接执行脚本 .\azureloadbalancer_addvm.ps1                      #>
<#-----------------------------------------------------------------#>

#*******************************************************************#
# 定义脚本中所需的变量
#*******************************************************************#

# 新添加的虚机索引
$vmIndex = "3"
# 资源名称的前缀
$prodNamePrefix = "Nick"
$lowerProdNamePrefix = $prodNamePrefix.ToLower()

# vm user name
$userName = "nick"
# vm user public key
$sshPublicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCzO/q7SCCTdPou/Pj/IYyUXk1f1gQ5yhc1werRvivcSRDCnGPXnF3VaiuLdmXsbPscZBQ83wAs2rMZ8zEMDsSO+OGJcuQdJd7yuCfhwQ7ugasmhJ9PhxGK865HBY9iMJBE1cVyA6pZ2bKRLlNB375UB4NoFJkc4Nxsvpl0RunfD+YjupGDeFGrgGklgZAqb/DXY+zzvEIW6VUdWTpRYmP5DV6/hF4pBDB+ItA+eYi8BqJr8OSW/QUZsTe/9edOM1acHQi0HdZWpwSNT3xR75D4gGGdQOtRoj+EdapZtW3oUdkce3zKVWiMHq1dK601Lzz5UUU+VNRp4aKWP7AWHxp/ nick@u16os"

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

# Load Balancer Frontend 配置的名称
$frontendV4Name = "LBFrontendIPv4"
$frontendV6Name = "LBFrontendIPv6"

# Load Balancer Backend Poll 配置的名称
$backendAddressPoolV4Name = "LBBackendPoolIPv4"
$backendAddressPoolV6Name = "LBBackendPoolIPv6"

# Load Balancer Inbound NAT rules 配置名称的前缀
$natRulexV4Name = "NatRule-SSH-VM" + $vmIndex

# Availability Set 名称
$availabilitySetName = $prodNamePrefix + "LBAvailabilitySet"

# 虚拟网卡的名称
$nicxName = $prodNamePrefix + "IPv4IPv6Nic" + $vmIndex

# 虚机配置
$vmSize = "Standard_B2s"
$vmVersion = "18.04-LTS"
#$userName = "nick"
$userPassword = "123456"
#$sshPublicKey = ""
$vmxName = $prodNamePrefix + "LBVM" + $vmIndex
$vmxDiskName = $prodNamePrefix + "LBVM" + $vmIndex + "_OsDisk"
$storageAccountTypeName = "Standard_LRS"
$vmxComputerHostName = $lowerProdNamePrefix + "lbvm" + $vmIndex
$frontendPort = $vmIndex + "0022"


#*******************************************************************#
# 获取虚拟网络及其虚拟子网的实例
#*******************************************************************#

# 获取虚拟网络的实例
$vnet = Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $rgName
# 获取虚拟子网的实例
$backendSubnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet


#*******************************************************************#
# 获取 Load Balancer 及其子属性的实例
#*******************************************************************#
$loadbalancer = Get-AzureRmLoadBalancer -Name $lbName -ResourceGroupName $rgName

# 获取 Load Balancer 的 Backend pools 实例
$backendpoolipv4 = Get-AzureRmLoadBalancerBackendAddressPoolConfig -Name $backendAddressPoolV4Name -LoadBalancer $loadbalancer
$backendpoolipv6 = Get-AzureRmLoadBalancerBackendAddressPoolConfig -Name $backendAddressPoolV6Name -LoadBalancer $loadbalancer

# 获取 Load Balancer 的 Frontend IP 实例
$FEIPConfigv4 = Get-AzureRmLoadBalancerFrontendIpConfig -Name $frontendV4Name -LoadBalancer $loadbalancer
$FEIPConfigv6 = Get-AzureRmLoadBalancerFrontendIpConfig -Name $frontendV6Name -LoadBalancer $loadbalancer

# 在 Load Balancer 实例中添加新的 Inbound NAT rule
$loadbalancer | Add-AzureRmLoadBalancerInboundNatRuleConfig -Name $natRulexV4Name -FrontendIPConfiguration $FEIPConfigv4 -Protocol TCP -FrontendPort $frontendPort -BackendPort 22


#*******************************************************************#
# 在云端更新 Load Balancer 实例
#*******************************************************************#

# 在云端更新 Load Balancer 实例
$loadbalancer | Set-AzureRmLoadBalancer

# 获得更新后的 Load Balancer 实例
$loadbalancer = Get-AzureRmLoadBalancer -Name $lbName -ResourceGroupName $rgName
$inboundNATRulev4 = Get-AzureRmLoadBalancerInboundNatRuleConfig -Name $natRulexV4Name -LoadBalancer $loadbalancer


#*******************************************************************#
# 创建虚拟网卡
#*******************************************************************#
$nicIPv4 = New-AzureRmNetworkInterfaceIpConfig -Name "IPv4IPConfig" -PrivateIpAddressVersion "IPv4" -Subnet $backendSubnet -LoadBalancerBackendAddressPool $backendpoolipv4 -LoadBalancerInboundNatRule $inboundNATRulev4
$nicIPv6 = New-AzureRmNetworkInterfaceIpConfig -Name "IPv6IPConfig" -PrivateIpAddressVersion "IPv6" -LoadBalancerBackendAddressPool $backendpoolipv6
$nic = New-AzureRmNetworkInterface -Name $nicxName -IpConfiguration $nicIPv4,$nicIPv6 -ResourceGroupName $rgName -Location $location


#*******************************************************************#
# 创建虚拟机并分配新建的 NIC
#*******************************************************************#

# 获取 Availability Set
$availabilitySet = Get-AzureRmAvailabilitySet -Name $availabilitySetName -ResourceGroupName $rgName

# 创建用户 Credential
$securePassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
$userCred = New-Object System.Management.Automation.PSCredential ($userName, $securePassword)

# 创建虚机
$vm = New-AzureRmVMConfig -VMName $vmxName -VMSize $vmSize -AvailabilitySetId $availabilitySet.Id
$vm = Set-AzureRmVMOperatingSystem -VM $vm -Linux -ComputerName $vmxComputerHostName -Credential $userCred -DisablePasswordAuthentication
$vm = Set-AzureRmVMSourceImage -VM $vm -PublisherName Canonical -Offer UbuntuServer -Skus $vmVersion -Version "latest"
$vm = Set-AzureRmVMBootDiagnostics -VM $vm -Disable
$vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id -Primary
$vm = Set-AzureRmVMOSDisk -VM $vm -Name $vmxDiskName -CreateOption FromImage -StorageAccountType $storageAccountTypeName
Add-AzureRmVMSshPublicKey -VM $vm -KeyData $sshPublicKey -Path "/home/$userName/.ssh/authorized_keys"
New-AzureRmVM -ResourceGroupName $rgName -Location $location -VM $vm

Write-Host "Adding VM to Load Balancer is completed."