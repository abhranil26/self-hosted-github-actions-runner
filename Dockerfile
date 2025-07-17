FROM ghcr.io/actions/actions-runner:latest

# Copy custom entrypoint if needed
COPY entrypoint.sh /home/runner/entrypoint.sh
USER root
RUN chmod +x /home/runner/entrypoint.sh
USER runner

ENTRYPOINT ["/home/runner/entrypoint.sh"]