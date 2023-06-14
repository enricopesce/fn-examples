import io
import json
import logging
from fdk import response

def get_text_secret(secret_ocid):
    signer = oci.auth.signers.get_resource_principals_signer()
    try:
        client = oci.secrets.SecretsClient({}, signer=signer)
        secret_content = client.get_secret_bundle(secret_ocid).data.secret_bundle_content.content.encode('utf-8')
        decrypted_secret_content = base64.b64decode(secret_content).decode("utf-8")
    except Exception as ex:
        print("ERROR: failed to retrieve the secret content", ex, flush=True)
        raise
    return {"secret content": decrypted_secret_content}


def handler(ctx, data: io.BytesIO=None):
    logging.getLogger().info("function start")

    try:
        cfg = dict(ctx.Config())
        secret_ocid = cfg["ATP_PASSWORD_OCID"]
        logging.getLogger().info("Secret ocid = " + secret_ocid)
    except Exception as e:
        print('ERROR: Missing configuration keys, secret ocid and secret_type', e, flush=True)
        raise
        
    resp = get_text_secret(secret_ocid)

    logging.getLogger().info("function end")
    
    return response.Response(
        ctx, 
        response_data=resp,
        headers={"Content-Type": "application/json"}
    )
