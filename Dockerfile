# ===============================
# STAGE-1:
# ===============================

#Building Python packages sometimes requires heavy tools (like compilers and build utilities).
#"Slim" gives us just what Python needs—nothing more, nothing less.
FROM python:3.11-slim AS builder

# Prevent Python from writing .pyc files & enable unbuffered logging
# avoids temporary cache files cluttering up our container image.
ENV PYTHONDONTWRITEBYTECODE=1 \    
    # avoids Python to hold logs in a temporary buffer,
    PYTHONUNBUFFERED=1             

WORKDIR /app

#skip extra recommended software.
RUN apt-get update && apt-get install -y --no-install-recommends \ 
    build-essential \
    #delete the temporary package index files in the exact command layer.
    && rm -rf /var/lib/apt/lists/*                                 

# Leverage Docker layer caching for Python packages
COPY requirements.txt .

# Install dependencies into a virtual environment or isolated directory
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN python -m pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt


# ===============================
# STAGE-2:
# ===============================   
FROM python:3.11-slim AS runtime

# Prevent Python from writing .pyc files & enable unbuffered logging
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    PORT=8080

WORKDIR /app

RUN groupadd -r appgroup && useradd -r -g appgroup -s /sbin/nologin appuser

# Copy virtual environment and application code from builder
COPY --from=builder /opt/venv /opt/venv
COPY app/app.py /app

# app directory is owned by non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose the application port
EXPOSE 8080

# Built-in Container Health Check (Adjust port/path to match app.py)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health').read()" || exit 1

# Entrypoint/Cmd to launch the application using an WSGI server (or app runner)
CMD ["python", "app.py"]


