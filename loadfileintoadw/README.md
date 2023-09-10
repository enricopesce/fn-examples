Per creare l'infrastruttura devi precendentemente installare terraform e creare il file terraform.tfvars con tutte le variabilil definite in Variables.tf

Configurare OCI cli

https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliconfigure.htm

Configurare fn

https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsquickstartlocalhost.htm#functionsquickstartlocalhost

https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionscreatefncontext.htm

```console
fn create context <my-context> --provider oracle
fn use context <my-context>
fn update context oracle.profile <profile-name>
fn update context oracle.compartment-id <compartment-ocid>
fn update context api-url <api-endpoint>
fn update context registry <region-key>.ocir.io/<tenancy-namespace>/<repo-name-prefix>
docker login -u '<tenancy-namespace>/<user-name>' <region-key>.ocir.io
```

Per creare l'infrastruttura e creare un deployment in automatico della function:

```console
terraform plan -out release
terraform apply "release"
```

Comandi di utilita'

Svuotare un bucket

```console
oci os object bulk-delete -bn processed-bucket --parallel-operations-count 10
```

Visualizzare i dati salvati su autonomous

```sql
select JSON_VALUE(SENSORS.JSON_DOCUMENT, '$.id' returning NUMBER) as id,
       JSON_VALUE(SENSORS.JSON_DOCUMENT, '$.wind' returning NUMBER) as wind,
       JSON_VALUE(SENSORS.JSON_DOCUMENT, '$.temperature' returning NUMBER) as temperature,
       JSON_VALUE(SENSORS.JSON_DOCUMENT, '$.humidity' returning NUMBER) as humidity,
       JSON_VALUE(SENSORS.JSON_DOCUMENT, '$.date' returning TIMESTAMP) as time
from SENSORS
```