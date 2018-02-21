FROM continuumio/anaconda

# yes I have tried miniconda, I get a segfault that I simply cannot get rid of

# all credit to @alexbw for most of this
# Make sure we can see everything in conda before local install
ENV PATH /opt/conda/lib:/opt/conda/include:$PATH

# Get a newer build toolchain, sshfs, other stuff
RUN DEBIAN_FRONTEND=noninteractive apt-get update -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential\
 && apt-get install -y lsb-release\
 && apt-get install -y sshfs\
 && apt-get install -y git

RUN DEBIAN_FRONTEND=noninteractive export GCSFUSE_REPO=gcsfuse-`lsb_release -c -s` \
	&& echo "deb http://packages.cloud.google.com/apt $GCSFUSE_REPO main" | tee /etc/apt/sources.list.d/gcsfuse.list\
	&& curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
RUN DEBIAN_FRONTEND=noninteractive apt-get update -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y gcsfuse

# Build a little home for our code
ENV SRC /src
ENV PYTHONPATH /src
RUN mkdir -p $SRC

# Get our Python requirements (needed to build pyhsmm and pybasicbayes)
RUN conda install pip mpi4py click matplotlib gcc cython future -y

# Install moseq
COPY . $SRC/moseq2_model
#RUN pip install -e future
RUN pip install -e $SRC/moseq2_model --process-dependency-links

# fix bug in Conda matplotlib implementation
# https://github.com/ContinuumIO/anaconda-issues/issues/1068
RUN conda install pyqt=4.11
