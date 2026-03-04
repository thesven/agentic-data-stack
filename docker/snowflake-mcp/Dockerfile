FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim
RUN uv tool install snowflake-labs-mcp==1.3.5
CMD ["mcp-server-snowflake", \
     "--service-config-file", "/app/snowflake-config.yaml", \
     "--transport", "streamable-http", \
     "--host", "0.0.0.0", \
     "--port", "9000"]
