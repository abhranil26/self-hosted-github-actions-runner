FROM ghcr.io/actions/actions-runner:latest

COPY entrypoint.sh /home/runner/entrypoint.sh
COPY watchdog.sh /home/runner/watchdog.sh
USER root
RUN chmod +x /home/runner/entrypoint.sh /home/runner/watchdog.sh
USER runner

ENTRYPOINT ["/home/runner/entrypoint.sh"]
