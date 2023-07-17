import io
import oci
import base64
import logging
import oracledb
from fdk import response

def get_text_secret(secret_ocid):
    signer = oci.auth.signers.get_resource_principals_signer()
    client = oci.secrets.SecretsClient({}, signer=signer)
    secret_content = client.get_secret_bundle(secret_ocid).data.secret_bundle_content.content.encode('utf-8')
    decrypted_secret_content = base64.b64decode(secret_content).decode("utf-8")
    return decrypted_secret_content


def query(ATP_USERNAME, DB_DNS, TNS_ADMIN, ATP_PASSWORD):
    logging.getLogger().info("ATP_USERNAME = " + ATP_USERNAME)
    logging.getLogger().info("DB_DNS = " + DB_DNS)
    logging.getLogger().info("TNS_ADMIN = " + TNS_ADMIN)
    logging.getLogger().info("ATP_PASSWORD = " + ATP_PASSWORD)

    oracledb.defaults.config_dir = TNS_ADMIN
    oracledb.init_oracle_client()

    connection = oracledb.connect(user=ATP_USERNAME,
        password=ATP_PASSWORD,
        dsn=DB_DNS,
        config_dir=TNS_ADMIN,
        wallet_location=TNS_ADMIN,
        wallet_password=ATP_PASSWORD)
    
    print(connection.version)
    return "connected"


def handler(ctx, data: io.BytesIO=None):
    try:
        cfg = dict(ctx.Config())
        ATP_PASSWORD = get_text_secret(cfg["ATP_PASSWORD_OCID"])
        result = query(cfg["ATP_USERNAME"], cfg["DB_DNS"], cfg["TNS_ADMIN"], ATP_PASSWORD)
    except Exception as e:
        print('ERROR: Missing configuration keys, secret ocid and secret_type', e, flush=True)
        raise
        
    return response.Response(
        ctx, 
        response_data=result,
        headers={"Content-Type": "application/json"}
    )
