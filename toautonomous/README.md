To create the infrastructure you need to install terraform and create the terraform.tfvars file with the required variables defined on Variables.tf

https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionscreatefncontext.htm

fn create context oci --provider oracle
fn use context oci

https://cloud.oracle.com/identity/compartments
fn update context oracle.compartment-id <compartment-ocid>

fn update context api-url <api-endpoint>
fn update context api-url https://functions.eu-frankfurt-1.oci.oraclecloud.com
https://docs.oracle.com/en-us/iaas/api/#/en/functions/20181201/

fn update context registry <region-key>.ocir.io/<tenancy-namespace>/<repo-name-prefix>
<region-key> https://docs.oracle.com/en-us/iaas/Content/Registry/Concepts/registryprerequisites.htm#regional-availability
<tenancy-namespace> https://cloud.oracle.com/tenancy
<repo-name-prefix> a name of the repo in my case "functions"

fn update context oracle.image-compartment-id <compartment-ocid>

cat ~/.fn/contexts/oci.yaml

docker login -u '<tenancy-namespace>/<username>' <region-key>.ocir.io


```console
terraform apply
```