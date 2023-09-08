import os
import oci
from time import sleep
import numpy as np
import pandas as pd
from string import ascii_uppercase
from numpy.random import default_rng
import datetime
import uuid
from datetime import datetime
from random import randrange
from datetime import timedelta

round_precision = 3
nrows = 10
rand = default_rng()
array_3 = rand.choice(tuple(ascii_uppercase), size=(nrows, 5))
config = oci.config.from_file()
object_storage_client = oci.object_storage.ObjectStorageClient(config)
dir_path = 'tmp/'
elements = 10
start = 0
size = 10

d1 = datetime.strptime('1/1/2000 1:30 PM', '%m/%d/%Y %I:%M %p')
d2 = datetime.strptime('1/1/2023 4:50 AM', '%m/%d/%Y %I:%M %p')

dates = pd.date_range(d1,d2-timedelta(days=1),freq='d')
dates = dates.map(lambda timestamp: timestamp.isoformat())

while True:
    # 10 sensori che producono 10 dati casuali per data casuale
    for x in range(size):
        df = pd.DataFrame({
            'id': x,
            'wind': rand.integers(low=0, high=50, size=nrows),
            'temperature': rand.integers(low=-10, high=40, size=nrows),
            'humidity': rand.integers(low=0, high=100, size=nrows),
            'date': dates[start:elements]
        })
        df.to_csv(dir_path + str(uuid.uuid4()) + '.csv', index=None)
    
    # copia i file sul bucket
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
    start = elements
    elements = elements + 10
    sleep(1)