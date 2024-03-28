FROM ubuntu:22.04

RUN apt-get update && apt-get install -y mpich python3.9 python3-pip git less iputils* bc

WORKDIR /workspace

RUN git clone -b v1.0-rc1 --recurse-submodules https://github.com/mlcommons/storage.git && \
	cd storage && pip install --upgrade pip && \
	pip install -r dlio_benchmark/requirements.txt

WORKDIR /workspace/storage

ENV RDMAV_FORK_SAFE=1

RUN apt install -y vim

CMD ["/bin/bash"]
