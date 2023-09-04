import io
import oci
import base64
import logging
import oracledb
import json
import csv
from fdk import response

def get_text_secret(secret_ocid):
    signer = oci.auth.signers.get_resource_principals_signer()
    client = oci.secrets.SecretsClient({}, signer=signer)
    secret_content = client.get_secret_bundle(secret_ocid).data.secret_bundle_content.content.encode('utf-8')
    decrypted_secret_content = base64.b64decode(secret_content).decode("utf-8")
    return decrypted_secret_content


def store_data(source_bucket, objectName, nameSpace, cfg):
    signer = oci.auth.signers.get_resource_principals_signer()
    client = oci.object_storage.ObjectStorageClient(config={}, signer=signer)

    ATP_USERNAME = cfg["ATP_USERNAME"]
    DB_DNS = cfg["DB_DNS"]
    TNS_ADMIN = cfg["TNS_ADMIN"]
    ATP_PASSWORD = get_text_secret(cfg["ATP_PASSWORD_OCID"])

    logging.getLogger().debug("ATP_USERNAME = " + ATP_USERNAME)
    logging.getLogger().debug("DB_DNS = " + DB_DNS)
    logging.getLogger().debug("TNS_ADMIN = " + TNS_ADMIN)
    logging.getLogger().debug("ATP_PASSWORD = " + ATP_PASSWORD)

    oracledb.defaults.config_dir = TNS_ADMIN
    oracledb.init_oracle_client()

    connection = oracledb.connect(user=ATP_USERNAME,
        password=ATP_PASSWORD,
        dsn=DB_DNS,
        config_dir=TNS_ADMIN,
        wallet_location=TNS_ADMIN,
        wallet_password=ATP_PASSWORD)
    
    connection.autocommit = True

    logging.getLogger().debug(connection.version)
    soda = connection.getSodaDatabase()
    collection = soda.createCollection("SENSORS")

    logging.getLogger().debug("Searching for: " + nameSpace +
                                "/" + source_bucket + "/" + objectName)
    object = client.get_object(nameSpace, source_bucket, objectName)
    if object.status == 200:
        input_csv_text = str(object.data.text)
        reader = csv.DictReader(input_csv_text.split('\n'), delimiter=',')
        for row in reader:
            logging.getLogger().debug("INFO - inserting:")
            logging.getLogger().debug("INFO - " + json.dumps(row))
            collection.insertOne(json.dumps(row))


def move_object(source_bucket, destination_bucket, object_name, namespace):
    signer = oci.auth.signers.get_resource_principals_signer()
    objstore = oci.object_storage.ObjectStorageClient(config={}, signer=signer)
    objstore_composite_ops = oci.object_storage.ObjectStorageClientCompositeOperations(objstore)
    resp = objstore_composite_ops.copy_object_and_wait_for_state(
        namespace, 
        source_bucket, 
        oci.object_storage.models.CopyObjectDetails(
            destination_bucket=destination_bucket, 
            destination_namespace=namespace,
            destination_object_name=object_name,
            destination_region=signer.region,
            source_object_name=object_name
            ),
        wait_for_states=[
            oci.object_storage.models.WorkRequest.STATUS_COMPLETED,
            oci.object_storage.models.WorkRequest.STATUS_FAILED])
    if resp.data.status != "COMPLETED":
        raise Exception("cannot copy object {0} to bucket {1}".format(object_name,destination_bucket))
    else:
        resp = objstore.delete_object(namespace, source_bucket, object_name)
        print("INFO - Object {0} moved to Bucket {1}".format(object_name,destination_bucket), flush=True)


def handler(ctx, data: io.BytesIO=None):
    logging.basicConfig(level=logging.WARNING)
    cfg = dict(ctx.Config())
    try:
        destination_bucket = "processed-bucket"
        body = json.loads(data.getvalue())
        logging.getLogger().debug('body: ' + str(body))
        source_bucket = body["data"]["additionalDetails"]["bucketName"]
        nameSpace = body["data"]["additionalDetails"]["namespace"]
        objectName = body["data"]["resourceName"]
        store_data(source_bucket, objectName, nameSpace, cfg)
        move_object(source_bucket, destination_bucket, objectName, nameSpace)
    except (Exception, ValueError) as ex:
        logging.getLogger().debug('error parsing json payload: ' + str(ex))

    return response.Response(
        ctx, 
        response_data="",
        headers={"Content-Type": "application/json"}
    )

