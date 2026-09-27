# D2K-Compliant Dockerfile: AquaINFRA Dasymetric refinement of human population (OPTIMIZED + CRAN FIX)
#
# This configuration strictly adheres to the execution requirements of the D2K User Guide
# by using a dedicated ENTRYPOINT to receive arguments from the 'docker run' command.
#
# OPTIMIZATIONS APPLIED:
# 1. Uses conda's libmamba solver for fast Conda environment solving.
# 2. Installs 'eurostat' from CRAN to get the latest version and fix API errors.

# 1. Start from a miniconda base image
# Provides Python, Conda, and a Linux base environment to build on
# Pinned: 'latest' moved to a new base on 2026-08-28, and the pinned conda
# packages in environment.yml conflict with that base's libraries.
FROM continuumio/miniconda3:26.5.3-1

# 2. Set the working directory
WORKDIR /app

# 3. Copy the environment definition file
# Brings in the Conda environment specification that defines required packages
COPY .binder/environment.yml /app/environment.yml

# 4. Set the shell to BASH for robust command execution
# Ensures complex RUN commands (like chaining with &&) work reliably
SHELL ["/bin/bash", "-c"]

# 5-6. Create the Conda environment
# Installs all dependencies defined in environment.yml. This installs all packages *except* eurostat. Cleans cache to reduce image size.
# conda already uses the fast libmamba solver. Installing mamba separately first
# broke the build: it pulls in libxml2-16, whose libxml2.so.16 is then deleted
# when the base image's own libxml2 package is replaced in this step.
RUN conda env update -n base -f /app/environment.yml && \
    conda clean --all -f -y

# 7a. (FIX) Install libgomp1, the OpenMP runtime R needs at runtime
# The miniconda3 base image is a slim Debian image and does not ship this by default,
# causing 'libgomp.so.1: cannot open shared object file' when R starts.
RUN apt-get update && apt-get install -y --no-install-recommends libgomp1 && \
    rm -rf /var/lib/apt/lists/*

# 7b. (FIX) Install the latest 'eurostat' from CRAN
# This bypasses the conda-forge version issue and fixes the '410 Gone' API error.
# Pinned to the version verified against the live Eurostat API (Sept 2026).
RUN /opt/conda/bin/R -e "remotes::install_version('eurostat', version='4.1.1', repos='https://cloud.r-project.org/', dependencies=TRUE, upgrade='never'); if (!requireNamespace('eurostat', quietly=TRUE)) quit(status=1)"

# 8. Copy R scripts (reusable functions) into the standard D2K source folder
# Adds reusable R scripts into the container
COPY src/ /app/src/

# 9. Copy the entrypoint script and fix its line endings
# Makes script executable. Removes Windows CRLF line endings (prevents Linux execution errors). 
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh && sed -i 's/\r$//' /app/entrypoint.sh

# 10. Set the R library path explicitly
# Ensures R looks in the correct library directory inside Conda
ENV R_LIBS_USER="/opt/conda/lib/R/library"

# 11. (D2K-COMPLIANT FIX) Set the ENTRYPOINT
# This tells Docker to run our script and pass the 'docker run' args to it. Defines the main executable for the container. This makes the container behave like a command-line tool.
ENTRYPOINT ["/app/entrypoint.sh"]

# 12. Set a default empty CMD (best practice with ENTRYPOINT)
# Allows arguments to be passed cleanly without overriding the entrypoint.
CMD []
