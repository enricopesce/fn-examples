#!/usr/bin/env python3
# coding: utf-8
# COPYRIGHT (c) 2020 ORACLE A-TEAM
# THIS SAMPLE CODE IS PROVIDED FOR EDUCATIONAL PURPOSES OR
# TO ASSIST YOUR DEVELOPMENT OR ADMINISTRATION EFFORTS AND
# PROVIDED "AS IS" AND IS NOT SUPPORTED BY ORACLE CORPORATION.
# License: http://www.apache.org/licenses/LICENSE-2.0.html

import oci
import base64
import sys

# Replace secret_id value below with the ocid of your secret
secret_id = "ocid1.vaultsecret.oc1.eu-frankfurt-1.amaaaaaaugtyopiadq3nu372rs6mm3umjoflcbwccczloehaeoszstb3cowa"

# By default this will hit the auth service in the region the instance is running.
signer = oci.auth.signers.InstancePrincipalsSecurityTokenSigner()

# In the base case, configuration does not need to be provided as the region and tenancy are obtained from the InstancePrincipalsSecurityTokenSigner
identity_client = oci.identity.IdentityClient(config={}, signer=signer)

# Get instance principal context
secret_client = oci.secrets.SecretsClient(config={}, signer=signer)

# Retrieve secret
def read_secret_value(secret_client, secret_id):
    response = secret_client.get_secret_bundle(secret_id)
    base64_Secret_content = response.data.secret_bundle_content.content
    base64_secret_bytes = base64_Secret_content.encode('ascii')
    base64_message_bytes = base64.b64decode(base64_secret_bytes)
    secret_content = base64_message_bytes.decode('ascii')
    return secret_content

# Print secret
secret_contents = read_secret_value(secret_client, secret_id)
print(format(secret_contents))