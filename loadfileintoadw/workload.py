import os
import oci
from time import sleep
import numpy as np
import pandas as pd
from string import ascii_uppercase
from numpy.random import default_rng
import datetime
import uuid

round_precision = 3
nrows = 10
rand = default_rng()
array_3 = rand.choice(tuple(ascii_uppercase), size=(nrows, 5))
config = oci.config.from_file()
object_storage_client = oci.object_storage.ObjectStorageClient(config)
dir_path = 'tmp/'
z = 0

while True:
    for x in range(int(rand.integers(low=1, high=10))):
        date = (datetime.datetime.utcnow() - datetime.timedelta(days=z))
        df = pd.DataFrame({
            'id': rand.integers(low=1, high=10, size=nrows),
            'wind': rand.integers(low=0, high=50, size=nrows),
            'temperature': rand.integers(low=-10, high=40, size=nrows),
            'humidity': rand.integers(low=0, high=100, size=nrows),
            'date': date.isoformat()
        })
        df.to_csv(dir_path + str(uuid.uuid4()) + '.csv', index=None)
    
    for path in os.scandir(dir_path):
        if path.is_file():
            with open(dir_path + path.name, "rb") as input_file:
                put_object_response = object_storage_client.put_object(
                namespace_name="frddomvd8z4q",
                bucket_name="input-bucket",
                put_object_body=input_file,
                object_name=path.name)
                print(put_object_response.headers)
                os.remove(dir_path + path.name)
    z = z+1
    sleep(10)