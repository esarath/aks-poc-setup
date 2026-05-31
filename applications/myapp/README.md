# Sample Application for AKS POC

This is a lightweight Flask application designed to demonstrate containerization, database integration, and monitoring in the AKS POC environment.

## Features

- RESTful API with CRUD operations
- PostgreSQL database integration
- Prometheus metrics for monitoring
- Health check endpoint
- Docker containerization
- Helm chart for Kubernetes deployment

## Prerequisites

- Python 3.11+
- PostgreSQL database (optional for local development)
- Docker (for containerization)

## Local Development

### Installation

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### Running Locally

```bash
# Set environment variables (optional)
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=appdb
export DB_USER=postgres
export DB_PASSWORD=your_password

# Run the application
python app.py
```

The application will be available at `http://localhost:8080`

### Testing

```bash
# Run tests
python -m pytest tests/

# Or using unittest
python -m unittest tests.test_app
```

## API Endpoints

### Health Check
```
GET /health
```

Returns health status of the application and database.

### Users API
```
GET    /api/users          - List all users
POST   /api/users          - Create a new user
GET    /api/users/{id}     - Get specific user
DELETE /api/users/{id}     - Delete user
```

Example user creation:
```bash
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","email":"john@example.com"}'
```

### Statistics
```
GET /api/stats
```

Returns application statistics including user count and request metrics.

### Metrics
```
GET /metrics
```

Returns Prometheus metrics in the standard format.

## Docker

### Build Image
```bash
docker build -t myapp:latest .
```

### Run Container
```bash
docker run -p 8080:8080 \
  -e DB_HOST=your_db_host \
  -e DB_NAME=appdb \
  -e DB_USER=postgres \
  -e DB_PASSWORD=your_password \
  myapp:latest
```

### Push to Docker Hub
```bash
docker tag myapp:latest esarathmails/aks-poc-app:latest
docker push esarathmails/aks-poc-app:latest
```

## Kubernetes Deployment

The application is packaged as a Helm chart in `../helm-charts/myapp`.

### Deploy to Kubernetes
```bash
helm install myapp ../helm-charts/myapp \
  --namespace production \
  --create-namespace \
  --values ../helm-charts/myapp/values-prod.yaml
```

### Upgrade Deployment
```bash
helm upgrade myapp ../helm-charts/myapp \
  --namespace production \
  --values ../helm-charts/myapp/values-prod.yaml
```

## Monitoring

The application exposes Prometheus metrics on port 8000:

- `http_requests_total`: Total number of HTTP requests
- `http_request_duration_seconds`: HTTP request latency histogram
- `db_connection_errors_total`: Database connection error count

## Configuration

### Environment Variables

- `DB_HOST`: Database host (default: localhost)
- `DB_PORT`: Database port (default: 5432)
- `DB_NAME`: Database name (default: appdb)
- `DB_USER`: Database user (default: postgres)
- `DB_PASSWORD`: Database password (required)
- `DB_SSLMODE`: SSL mode for database connection (default: prefer)

### Application Configuration

The application can be configured via ConfigMap values in the Helm chart.

## Troubleshooting

### Database Connection Issues
- Verify database is accessible from the pod
- Check environment variables are set correctly
- Review pod logs: `kubectl logs <pod-name> -n production`

### Health Check Failures
- Check if database is healthy
- Verify network connectivity
- Review application logs

### Metrics Not Available
- Ensure metrics service is running on port 8000
- Check ServiceMonitor configuration
- Verify Prometheus is scraping the metrics endpoint

## License

This is a sample application for demonstration purposes.