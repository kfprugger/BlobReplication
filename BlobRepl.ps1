#$primary = Get-AutomationVariable -Name 'Log-Storage-Primary'
#$secondary = Get-AutomationVariable -Name 'Log-Storage-Secondary'

$primary = "blobsrcrobrake"
$secondary = "blobdestrobrak"
#$azautomationRG = "RG-Mgmt"
#$azautomationaccountname = "azautoworker"
$blobRG = "RG-Mgmt"
$Modifiedcount = 0
$createdCount = 0


# needed if you define a specifc container in line 25
#$srccontainer = "blobsrc"

# uncomment if you need to connect using a SP. For automation, prefer to use Azure Automation Service Prinicpal
#$svcprin = Get-AzureRmAutomationConnection -Name AzureRunAsConnection -ResourceGroupName $azautomationRG -AutomationAccountName $azautomationaccountname

$primarykey = Get-AzureRmStorageAccountKey -ResourceGroupName $blobRG -Name $primary
$secondarykey = Get-AzureRmStorageAccountKey -ResourceGroupName $blobRG -Name $secondary

$primaryctx = New-AzureStorageContext -StorageAccountName $primary -StorageAccountKey $primarykey[0].Value
$secondaryctx = New-AzureStorageContext -StorageAccountName $secondary -StorageAccountKey $secondarykey[0].Value

# define specific container ... 
#$primarycontainers = $srccontainer 
#$primarycontainers = Get-AzureStorageContainer -Name $srccontainer -Context $primaryctx
# ...or loop through all blob containers in the storage account"
$primarycontainers = Get-AzureStorageContainer -Context $primaryctx

# Loop through each of the containers16

foreach($container in $primarycontainers)
{
# Do a quick check to see if the secondary container exists, if not, create it.
$secContainer = Get-AzureStorageContainer -Name $container.Name -Context $secondaryctx -ErrorAction SilentlyContinue
if (!$secContainer)
{
$secContainer = New-AzureStorageContainer -Context $secondaryctx -Name $container.Name
Write-Host "Successfully created Container" $secContainer.Name "in Account" $secondary
}

# Loop through all of the objects within the container and copy them to the same container on the secondary account
$primaryblobs = Get-AzureStorageBlob -Container $container.Name -Context $primaryctx

foreach($blob in $primaryblobs)
{
$copyblob = Get-AzureStorageBlob -Context $secondaryctx -Blob $blob.Name -Container $container.Name -ErrorAction SilentlyContinue

# Check to see if the blob exists in the secondary account or if it has been updated since the last runtime.
if (!$copyblob -or $blob.LastModified -gt $copyblob.LastModified) {
$copyblob = Start-AzureStorageBlobCopy -SrcBlob $blob.Name -SrcContainer $container.Name -Context $primaryctx -DestContainer $secContainer.Name -DestContext $secondaryctx -DestBlob $blob.Name -Force
$Modifiedcount++

$status = $copyblob | Get-AzureStorageBlobCopyState
while ($status.Status -eq "Pending")
{
$status = $copyblob | Get-AzureStorageBlobCopyState
Start-Sleep 10
}

Write-Host "Successfully copied blob" $copyblob.Name "to Account" $secondary "in container" $container.Name

}
$createdCount++
}

Write-Host "Modfied Files updated in " $secondary " is:" $Modifiedcount


}