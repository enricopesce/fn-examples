FROM fnproject/python:3.9

WORKDIR /function

RUN microdnf install oracle-instantclient-release-el8 &&\
    microdnf install oracle-instantclient-basic unzip &&\
    microdnf clean all

ADD requirements.txt /function/

RUN pip3 install --target /python/ --no-cache --no-cache-dir -r requirements.txt &&\
    rm -fr ~/.cache/pip /tmp* requirements.txt .venv &&\
    chmod -R o+r /python

ADD . /function/

RUN chmod -R o+r /function

# RUN unzip wallet.zip -d /function/wallet
# RUN sed -i 's/\?\/network\/admin/\/function\/wallet/g' /function/wallet/sqlnet.ora

ENV PYTHONPATH=/function:/python
ENV PATH=/usr/lib/oracle/21/client64/bin:$PATH
ENV TNS_ADMIN=/function/wallet

ENTRYPOINT ["/python/bin/fdk", "/function/func.py", "handler"]
