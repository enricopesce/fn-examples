Andiamo a creare le risorse necessarie


Creiamo il bucket 
```console
export compartment_id=ocid1.compartment.oc1..aaaaaaaawdnpqa74qyku5mzjk3httbooikrw67cbutdsohf2ljxkdyjvbala
export bucket_name=read-bucket
export namespace_name=frddomvd8z4q
export subnet_id=ocid1.subnet.oc1.eu-frankfurt-1.aaaaaaaaluabnf7xyaug7xna2vsxn3x3jh2eefaco5pwaizrgvu54kfzoy2q

oci os bucket create --compartment-id $compartment_id --name $bucket_name --namespace-name $namespace_name --object-events-enabled true
oci fn application create --compartment-id $compartment_id --display-name $bucket_name --subnet-ids '["ocid1.subnet.oc1.eu-frankfurt-1.aaaaaaaaluabnf7xyaug7xna2vsxn3x3jh2eefaco5pwaizrgvu54kfzoy2q"]'
```

Creiamo la funzione
```console
oci fn application create --compartment-id $compartment_id --display-name $bucket_name --subnet-ids '["ocid1.subnet.oc1.eu-frankfurt-1.aaaaaaaaluabnf7xyaug7xna2vsxn3x3jh2eefaco5pwaizrgvu54kfzoy2q"]'

deploy etc
```

Creiamo l'event rule

```console
export condition='{"eventType":["com.oraclecloud.objectstorage.createobject"],"data":{"bucketName":"read-bucket"}}'

oci events rule create --actions file://actions.json --compartment-id $compartment_id --condition $condition --display-name readBucket --is-enabled true
```

Creiamo log

```console

```