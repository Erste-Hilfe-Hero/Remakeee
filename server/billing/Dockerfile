# Billing service (plan area 10): Python stdlib + cryptography, psql for the database calls.
FROM python:3.13-slim
RUN apt-get update -q && DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends postgresql-client \
	&& rm -rf /var/lib/apt/lists/* \
	&& pip install --no-cache-dir cryptography==44.0.3 \
	&& useradd --system --no-create-home --uid 10001 billing
WORKDIR /app
COPY apple.py google.py billing.py ./
USER billing
EXPOSE 8080
CMD ["python3", "-u", "/app/billing.py"]
