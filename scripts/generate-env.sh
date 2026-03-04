#!/bin/bash

# Script to generate cryptographically random credentials for all services
# This creates a .env file with secure passwords and keys

set -e

echo "Generating cryptographically random credentials..."

# Generate Phoenix database password
PHOENIX_DB_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)

# Generate LibreChat-specific credentials
LIBRECHAT_PORT=${LIBRECHAT_PORT:-3080}
RAG_PORT=${RAG_PORT:-8001}
MEILI_MASTER_KEY=$(openssl rand -hex 32)
VECTORDB_DB=${VECTORDB_DB:-librechat_vectordb}
VECTORDB_USER=${VECTORDB_USER:-vectordb_user}
VECTORDB_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)

# Generate LibreChat JWT secrets
JWT_SECRET=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)
JWT_REFRESH_SECRET=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)

# User credentials
USER_EMAIL=${USER_EMAIL:-admin@admin.com}
USER_PASSWORD=${USER_PASSWORD:-password}
USER_NAME=${USER_NAME:-Admin}

# Write to .env file
cat > .env << EOF
# Auto-generated credentials - $(date)
# DO NOT COMMIT THIS FILE - It contains secrets!

# ============================================
# Phoenix Configuration (LLM Observability)
# ============================================
PHOENIX_DB_USER=phoenix
PHOENIX_DB_PASSWORD=${PHOENIX_DB_PASSWORD}
PHOENIX_DB_NAME=phoenix

# ============================================
# LiteLLM Proxy Configuration
# ============================================
# Optional: set a master key to protect the LiteLLM admin API
# LITELLM_MASTER_KEY=

# ============================================
# MCP Toolbox — Data Warehouse Configuration
# ============================================
# Uncomment the section(s) for your warehouse and configure tools.yaml to match.
# BigQuery
# GCP_CREDENTIALS_FILE=./secrets/gcp-service-account.json
# Store key files outside the repo or under ./secrets/ (gitignored).
# Snowflake (shared by both MCP servers)
# SNOWFLAKE_ACCOUNT=your-account.us-east-1
# SNOWFLAKE_USER=
# SNOWFLAKE_PASSWORD=
# SNOWFLAKE_ROLE=
# SNOWFLAKE_WAREHOUSE=COMPUTE_WH
# SNOWFLAKE_DATABASE=

# Snowflake RSA Key-Pair Auth (Snowflake Labs MCP only)
# SNOWFLAKE_PRIVATE_KEY=
# SNOWFLAKE_PRIVATE_KEY_FILE_PWD=
# ClickHouse (external)
# TOOLBOX_CLICKHOUSE_USER=
# TOOLBOX_CLICKHOUSE_PASSWORD=

# ============================================
# LibreChat Configuration
# ============================================
LIBRECHAT_PORT=${LIBRECHAT_PORT}
RAG_PORT=${RAG_PORT}
MEILI_MASTER_KEY=${MEILI_MASTER_KEY}
VECTORDB_DB=${VECTORDB_DB}
VECTORDB_USER=${VECTORDB_USER}
VECTORDB_PASSWORD=${VECTORDB_PASSWORD}

# ============================================
# LibreChat Authentication
# ============================================
JWT_SECRET=${JWT_SECRET}
JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}

# LibreChat Initial User
LIBRECHAT_USER_EMAIL=${USER_EMAIL}
LIBRECHAT_USER_PASSWORD=${USER_PASSWORD}
LIBRECHAT_USER_NAME=${USER_NAME}

# LibreChat Encryption Keys (required for encrypting user API keys)
# CREDS_KEY: 64-character hex string (32 bytes) for AES-256 encryption
# CREDS_IV: 32-character hex string (16 bytes) for AES-CBC initialization vector
CREDS_KEY=$(openssl rand -hex 32)
CREDS_IV=$(openssl rand -hex 16)

# LibreChat API Keys - Set to "user_provided" to allow users to configure their own keys in the UI
ANTHROPIC_API_KEY=user_provided
GOOGLE_KEY=user_provided
OPENAI_API_KEY=user_provided

EOF

echo ""
echo "✅ Credentials generated successfully!"
echo ""
echo "📝 Generated .env file with:"
echo "   - Phoenix database password"
echo "   - LibreChat JWT secrets"
echo "   - LibreChat encryption keys"
echo "   - Meilisearch master key"
echo "   - VectorDB password"
echo "   - Initial user credentials (preset)"
echo ""
echo "👤 Preset User Credentials:"
echo "   Email: ${USER_EMAIL}"
echo ""
echo "💡 To customize credentials, run with environment variables:"
echo "   USER_EMAIL=your@email.com USER_PASSWORD=yourpass USER_NAME=yourname ./scripts/generate-env.sh"
echo ""
echo "📡 MCP Toolbox will be available at: http://toolbox-mcp:5000"
echo "   Configure your warehouse in tools.yaml"
echo ""
echo "💬 LibreChat will be available at: http://localhost:${LIBRECHAT_PORT}"
echo "🔭 Phoenix will be available at: http://localhost:6006"
echo "🔀 LiteLLM Proxy will be available at: http://localhost:4000"
echo ""
echo "📝 LibreChat Initial User:"
echo "   Email: ${USER_EMAIL}"
echo "   Password: ${USER_PASSWORD}"
echo "   Name: ${USER_NAME}"
echo "   Role: ADMIN (set automatically)"
echo ""
