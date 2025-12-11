# Tailscale MCP Agent - Dockerfile
# 
# Multi-stage build for smaller final image

# ============================================================================
# Stage 1: Builder
# ============================================================================
FROM python:3.11-slim AS builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# ============================================================================
# Stage 2: Runtime
# ============================================================================
FROM python:3.11-slim AS runtime

# Labels
LABEL maintainer="Ebad"
LABEL description="Tailscale MCP Agent - Execute remote commands via Claude"
LABEL version="0.1.0"

# Create non-root user for security
RUN useradd --create-home --shell /bin/bash agent

WORKDIR /app

# Install runtime dependencies (SSH client for key handling)
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /home/agent/.ssh \
    && chown -R agent:agent /home/agent/.ssh \
    && chmod 700 /home/agent/.ssh

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy application code
COPY --chown=agent:agent src/ ./src/
COPY --chown=agent:agent config/ ./config/
COPY --chown=agent:agent run.py .
COPY --chown=agent:agent check_setup.py .

# Create directory for SSH keys (will be mounted as volume)
RUN mkdir -p /app/ssh-keys && chown agent:agent /app/ssh-keys

# Switch to non-root user
USER agent

# Environment variables (defaults, override with docker-compose or -e)
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV GRADIO_SERVER_NAME=0.0.0.0
ENV GRADIO_SERVER_PORT=7860

# Expose Gradio port
EXPOSE 7860

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:7860/')" || exit 1

# Default command
CMD ["python", "run.py"]