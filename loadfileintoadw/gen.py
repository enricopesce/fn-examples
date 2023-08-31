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

c = 100

for x in range(100):
    date = datetime.datetime.utcnow() + datetime.timedelta(days=x)
    df = pd.DataFrame({
        'id': rand.integers(low=1, high=10, size=nrows),
        'wind': rand.integers(low=0, high=100, size=nrows),
        'temperature': rand.integers(low=-10, high=40, size=nrows),
        'humidity': rand.integers(low=0, high=100, size=nrows),
        'date': date.isoformat()
    })

    df.to_csv("data/" + str(uuid.uuid4()) + '.csv', index=None)