import io
import json
import logging
from fdk import response
import oci.object_storage


def get_object(bucketName, objectName, nameSpace):
    message = ""
    signer = oci.auth.signers.get_resource_principals_signer()
    client = oci.object_storage.ObjectStorageClient(config={}, signer=signer)
    try:
        logging.getLogger().info("Searching for: " + nameSpace +
                                 "/" + bucketName + "/" + objectName)
        object = client.get_object(nameSpace, bucketName, objectName)
        if object.status == 200:
            message = object.data.text
            logging.getLogger().info("Success: The object " + objectName +
                                     " was retrieved with the content: " + message)
        else:
            message = "Failed: The object " + objectName
            logging.getLogger().info("Failed: The object " + objectName +
                                     + " could not be retrieved.")
    except Exception as ex:
        logging.getLogger().info('error: ' + str(ex))
    return {"content": message}


def handler(ctx, data: io.BytesIO = None):
    try:
        body = json.loads(data.getvalue())
        logging.getLogger().info('body: ' + str(body))
        bucketName = body["data"]["additionalDetails"]["bucketName"]
        nameSpace = body["data"]["additionalDetails"]["namespace"]
        objectName = body["data"]["resourceName"]
    except (Exception, ValueError) as ex:
        logging.getLogger().info('error parsing json payload: ' + str(ex))
    resp = get_object(bucketName, objectName, nameSpace)
    return response.Response(
        ctx,
        response_data=json.dumps(resp),
        headers={"Content-Type": "application/json"}
    )
