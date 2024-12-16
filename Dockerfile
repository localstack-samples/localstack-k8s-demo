FROM python:3.12-slim
RUN pip install kopf kubernetes
ADD ./localstack_operator.py /src/localstack_operator.py
CMD ["kopf", "run", "/src/localstack_operator.py", "--verbose"]
