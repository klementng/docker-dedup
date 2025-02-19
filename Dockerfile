# Use the base image
FROM docker.io/ubuntu:jammy

# Update and install required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends rdfind cron && \
    rm -rf /var/lib/apt/lists/*


# Copy your entrypoint script to the cont-init.d directory
COPY entrypoint.sh /entrypoint.sh 

# Ensure the script is executable
RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh 

ENTRYPOINT [ "/entrypoint.sh" ]
