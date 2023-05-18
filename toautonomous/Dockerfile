FROM fnproject/python:3.9
WORKDIR /function
ADD requirements.txt /function/

RUN pip3 install --target /python/ --no-cache --no-cache-dir -r requirements.txt &&\
    rm -fr ~/.cache/pip /tmp* requirements.txt func.yaml Dockerfile .venv &&\
    chmod -R o+r /python

ADD . /function/

RUN microdnf install oracle-instantclient-release-el8 &&\
    microdnf install oracle-instantclient-basic &&\
    microdnf clean all

RUN chmod -R o+r /function

ENV PYTHONPATH=/function:/python
ENV PATH=/usr/lib/oracle/21/client64/bin:$PATH
ENV TNS_ADMIN=/function/wallet

ENTRYPOINT ["/python/bin/fdk", "/function/func.py", "handler"]