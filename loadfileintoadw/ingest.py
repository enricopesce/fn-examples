import os
import oci
from time import sleep

config = oci.config.from_file()
object_storage_client = oci.object_storage.ObjectStorageClient(config)

# get all files inside a specific folder
dir_path = r'data'
for path in os.scandir(dir_path):
    if path.is_file():
        print(path.name)
        with open("data/" + path.name, "rb") as input_file:
            put_object_response = object_storage_client.put_object(
            namespace_name="frddomvd8z4q",
            bucket_name="processed-bucket",
            put_object_body=input_file,
            object_name=path.name)
            print(put_object_response.headers)
        sleep(60)