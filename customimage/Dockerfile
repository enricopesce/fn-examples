FROM fnproject/python:3.9
WORKDIR /function
ADD requirements.txt /function/

RUN pip3 install --target /python/ --no-cache --no-cache-dir -r requirements.txt &&\
    rm -fr ~/.cache/pip /tmp* requirements.txt func.yaml Dockerfile .venv &&\
    chmod -R o+r /python

# install Oracle database client
RUN microdnf install oracle-instantclient-release-el8 &&\
    microdnf install oracle-instantclient-basic &&\
    microdnf clean all

ADD . /function/

RUN chmod -R o+r /function

ENV PYTHONPATH=/function:/python

ENTRYPOINT ["/python/bin/fdk", "/function/func.py", "handler"]