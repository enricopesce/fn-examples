This example describe how you can extend or change the fn project docker files.

In the specific i have created a Dockerfile in the root project directory and changed the func.yaml to address the custom Docker file.

In this way you can install more packages or change some enviromente configuration, or drastically replace all.

First time command:

```console
fn create context <my-context> --provider oracle
fn use context <my-context>
fn update context oracle.profile <profile-name>
fn update context oracle.compartment-id <compartment-ocid>
fn update context api-url <api-endpoint>
fn update context registry <region-key>.ocir.io/<tenancy-namespace>/<repo-name-prefix>
docker login -u '<tenancy-namespace>/<user-name>' <region-key>.ocir.io
```

```console
fn create app <app-name> --annotation oracle.com/oci/subnetIds='["<sunbet-ocid>"]'
```

Deploy the infrastructure
```console
terraform init
terraform apply
```

Invoke the function
```console
echo -n '{"name": "Oracle"}' | fn invoke custom_image customimage
```

