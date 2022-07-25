#!/bin/bash

echo "source subscription-id $1"
echo "source resource group $2"
echo "target subscription-id $3"
echo "target resource group $4"
echo "Source AKS instance name $5"
echo "Number of instance $9"

rm pvc-snapshot.yaml
rm pvc-restore-from-snapshot.yaml

echo "Load the AKS profile for cluster $5 under resource group $6"
az aks get-credentials --resource-group $6 --name $5

cat template/storageclass-azuredisk-snapshot.yaml >> pvc-snapshot.yaml
cat template/storageclass-azuredisk-snapshot.yaml >> pvc-restore-from-snapshot.yaml

i=0
while [ $i -ne $9 ]
do
        sed "s/INSTANCENAME/tg-data-tigergraph-$i/g" template/volumesnapshot.yaml >> pvc-snapshot.yaml

        # increment the counter
        i=$(($i+1))
done

echo "Start PVC snapshot for $5 AKS instance"
# create the volumne snapshot for the aks cluster $5
kubectl apply -f pvc-snapshot.yaml
echo "Finished PVC snapshot"

# The following block would continue until all the snapshots have been successfully created
i=0
while [ $i -ne $9 ]
do

        #Provide the name of your resource group where snapshot exists
        sourceResourceGroupName=$2

        #Provide the name of the snapshot
	snapshotName=`kubectl get volumesnapshots | grep "snapshot-tg-data-tigergraph-$i" | awk '{print $6}' | sed "s/snapcontent/snapshot/g"`

	echo "check if the snapshot(apshot-tg-data-tigergraph-$i) has been created "
	#Get the snapshot Id
        snapshotId=$(az snapshot show --name $snapshotName --resource-group $sourceResourceGroupName --query [id] -o tsv)

        #If snapshotId is blank then it means that snapshot does not exist.
        echo 'source snapshot Id is: ' $snapshotId

	if [ -z "$snapshotId" ]
	then	
		echo "sleep for 30 seconds"
		sleep 30
		echo "check again if the snapshots are created"
	else
		# increment the counter
	        i=$(($i+1))
	fi
done

declare -a tgtSnapshotIds=()
i=0
while [ $i -ne $9 ]
do
	#Provide the subscription Id of the subscription where snapshot exists
	sourceSubscriptionId=$1

	#Provide the name of your resource group where snapshot exists
	sourceResourceGroupName=$2

	#Provide the name of the snapshot
	snapshotName=`kubectl get volumesnapshots | grep "snapshot-tg-data-tigergraph-$i" | awk '{print $6}' | sed "s/snapcontent/snapshot/g"`
	targetSnapshotName="snapshot-$i"
	#Set the context to the subscription Id where snapshot exists
	az account set --subscription $sourceSubscriptionId

	#Get the snapshot Id 
	snapshotId=$(az snapshot show --name $snapshotName --resource-group $sourceResourceGroupName --query [id] -o tsv)

	#If snapshotId is blank then it means that snapshot does not exist.
	echo 'source snapshot Id is: ' $snapshotId

	#Provide the subscription Id of the subscription where snapshot will be copied to
	#If snapshot is copied to the same subscription then you can skip this step
	targetSubscriptionId=$3

	#Name of the resource group where snapshot will be copied to
	targetResourceGroupName=$4

	#Set the context to the subscription Id where snapshot will be copied to
	#If snapshot is copied to the same subscription then you can skip this step
	az account set --subscription $targetSubscriptionId

	#Copy snapshot to different subscription using the snapshot Id
	#We recommend you to store your snapshots in Standard storage to reduce cost. Please use Standard_ZRS in regions where zone redundant storage (ZRS) is available, otherwise use Standard_LRS
	#Please check out the availability of ZRS here: https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy-zrs#support-coverage-and-regional-availability
	#targetSnapshotId=$(az snapshot create --resource-group $targetResourceGroupName --name $snapshotName --source $snapshotId --sku Standard_ZRS --incremental --query id -o tsv  --copy-start)
	
	#targetSnapshotId=1
	targetSnapshotId=$(az snapshot create --resource-group $targetResourceGroupName --name $targetSnapshotName --source $snapshotId --incremental --query id -o tsv  --copy-start)
	echo 'target snapshot Id is: ' $targetSnapshotId

	tgtSnapshotIds[$i]="$targetSnapshotId"

	sed "s/INSTANCENAME/tg-data-tigergraph-$i/g; s,TARGETSNAPSHOT,$targetSnapshotId,g" template/restorevolumesnapshot.yaml >> pvc-restore-from-snapshot.yaml
	# increment the counter 
	i=$(($i+1))
done
#: '
# check the copy completion status for the snapshots
 # check the copy completion status for the snapshots
for id in "${tgtSnapshotIds[@]}"
do
    echo "Check the completion status for snapshot $i"
    completionstatus="0"

    while [ "$completionstatus" != "100.0" ]; do
         #sleep for few seconds
         echo "sleep for 60 seconds"
         sleep 10
         #echo "check the completion percentage again "
         completionstatus=$(az snapshot show --ids $id --query [completionPercent] -o tsv)
         echo "Completion Percentage is $completionstatus for snapshot $id"
    done
done
#`
az aks get-credentials --resource-group $8 --name $7
# create the volumne snapshot for the aks cluster $7 in resource group $8
echo "Restore PVC snapshot to $7 AKS instance"
kubectl apply -f pvc-restore-from-snapshot.yaml
echo "Completed the restoration of PVC snapshot"
kubectl apply -f template/tigergraph-aks-default.yaml