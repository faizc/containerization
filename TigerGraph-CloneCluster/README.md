# TigerGraph - Clone cluster

This would be useful for users who want to clone the **TigerGraph** cluster running on Azure Kubernetes Service and would spin up look alike cluster along with the data. This would typically be required for teams who want to spin up cluster for few hours, perform some analytics and then tear down the cluster. 

# Sources

The source folder has script file and template folder that has yaml files. On execution of the **copysnapshot.sh** file, it would basically expect some parameters and would take snapshot of PVC of existing cluster and create new cluster and restore the PVC on the new cluster.  

## Execution

```
usage: ./copysnapshot.sh 
	<source-subscription id>
	<source-subscription resourcegroup>
	<target-subscription id>
	<target-subscription resourcegroup>
	<source-aks-instance-name>
	<number-of-nodes-in-existing-tigergraph-cluster>
```



## Execution Flow 


```mermaid
graph TD
A[Start] -- Delete old yaml files --> B(Clean up)
B -- Create blank yaml files --> C(Files created)
C -- Step 1 --> D{i <= number<br/> of nodes} -- copy --> E(copy 'template/volumesnapshot.yaml' <br/>to 'pvc-snapshot.yaml') -- continue --> D
D -- Step 2 --> F(Execute the  'pvc-snapshot.yaml' <br/>using kubectl apply command -<br/> Create PVC snapshot for existing cluster)
F  --> G{i <= number<br/> of nodes} -- check--> H(Check if the snapshot<br/> has been created) -- No --> I(Sleep for 30 seconds) -- check <br/>again--> H
H -- Yes --> G
G -- Step 3 --> J{i <= number<br/> of nodes} 
J -- loop --> K(Get the source snapshot Id) --> L(Create target snapshot<br/> using source snapshot id) --> M(copy 'template/restorevolumesnapshot.yaml'<br/> to 'pvc-restore-from-snapshot.yaml') -- repeat --> J
J -- Step 4--> O(pvc-restore-from-snapshot.yaml <br/> file created) -->P{i <= number<br/> of nodes} --> Q(Check if the snapshot<br/> has been created) -- No --> R(Sleep for 10 seconds) -- check <br/>again--> Q
Q -- Yes --> P
P -- Step 5--> T(Execute <br/>'pvc-restore-from-snapshot.yaml' using <br/>kubectl command)   --> U(Execute <br/>'template/tigergraph-aks-default.yaml' using <br/>kubectl command) --> V(Stop)
linkStyle 2 stroke-width:5px,fill:red,stroke:red;color:#fff
linkStyle 5 stroke-width:5px,stroke:red;color:#fff
linkStyle 11 stroke-width:5px,stroke:red;color:#fff
linkStyle 16 stroke-width:5px,stroke:red;color:#fff
linkStyle 22 stroke-width:5px,stroke:red;color:#fff
```


```