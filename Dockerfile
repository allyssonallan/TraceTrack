# Use a specific tag instead of the latest to ensure reproducibility.
FROM continuumio/miniconda3:4.9.2

# Combine apt-get update with apt-get install in the same RUN statement to avoid cached layers being out of date
# Install necessary packages and clean up in one RUN to minimize the image size
RUN apt-get update -y --allow-releaseinfo-change && apt-get install -y --no-install-recommends \
    libgtextutils-dev \
    libtbb-dev \
    autoconf \
    automake \
    libcurl4-gnutls-dev \
    libncurses5-dev \
    build-essential \
    pkg-config \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# It's a good practice to avoid using the root user. The user creation is moved up here to avoid running unnecessary commands as root.
RUN useradd -m docker && \
    mkdir -p /opt/suprseqr && \
    chown docker:docker /opt/suprseqr

# Copy only what is necessary
COPY --chown=docker:docker environment.yml /tmp/environment.yml

# Ensure the docker user has the necessary permissions
RUN chown -R docker:docker /opt/conda

# Switch to the docker user
USER docker

# Set the environment variable
ENV PATH /opt/miniconda/tracetrack:$PATH

# Use the base environment for conda and clean up in one layer to reduce image size
RUN conda env update -n base -f /tmp/environment.yml && \
    conda clean --all -f -y && \
    rm -rf /opt/miniconda/pkgs/*

WORKDIR /opt/suprseqr

# Copy the rest of the application
COPY --chown=docker:docker tracetrack tracetrack
COPY --chown=docker:docker data data
COPY --chown=docker:docker tests tests
COPY --chown=docker:docker resources resources
COPY --chown=docker:docker setup.py setup.py

# Install the application
RUN pip install .

# Set the Flask app environment variable
ENV FLASK_APP tracetrack.flask_server

# Use exec form of ENTRYPOINT to make sure signals are passed properly to the flask process
ENTRYPOINT ["/usr/bin/tini", "--"]

# Specify the default command to run the flask app
CMD ["flask", "run", "--host", "0.0.0.0"]
