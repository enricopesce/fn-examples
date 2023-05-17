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
fn create app pythonexamples --annotation oracle.com/oci/subnetIds='["<sunbet-ocid>"]'
```

```console
fn init --runtime python helloworld
```

```console
fn -v deploy --app hello
```

```console
echo -n '{"name": "Oracle"}' | fn invoke pythonexamples hello
```