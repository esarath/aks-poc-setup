#!/usr/bin/env python3
"""
Sample Flask Application for AKS POC
A lightweight web application with database integration and monitoring
"""

from flask import Flask, jsonify, request, render_template_string
import os
import psycopg2
from prometheus_client import Counter, Histogram, generate_latest, start_http_server
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'HTTP request latency')
DB_CONNECTION_ERRORS = Counter('db_connection_errors_total', 'Database connection errors')

# Database configuration
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_PORT = os.getenv('DB_PORT', '5432')
DB_NAME = os.getenv('DB_NAME', 'appdb')
DB_USER = os.getenv('DB_USER', 'postgres')
DB_PASSWORD = os.getenv('DB_PASSWORD', '')
DB_SSLMODE = os.getenv('DB_SSLMODE', 'prefer')

def get_db_connection():
    """Establish database connection"""
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            sslmode=DB_SSLMODE
        )
        return conn
    except Exception as e:
        logger.error(f"Database connection error: {e}")
        DB_CONNECTION_ERRORS.inc()
        raise

def initialize_database():
    """Initialize database tables"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Create users table
        cur.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                name VARCHAR(100) NOT NULL,
                email VARCHAR(100) UNIQUE NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Create requests table for tracking
        cur.execute("""
            CREATE TABLE IF NOT EXISTS requests (
                id SERIAL PRIMARY KEY,
                endpoint VARCHAR(100),
                method VARCHAR(10),
                status_code INTEGER,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        conn.commit()
        cur.close()
        conn.close()
        logger.info("Database initialized successfully")
    except Exception as e:
        logger.error(f"Database initialization error: {e}")
        raise

@app.route('/')
@REQUEST_LATENCY.time()
def index():
    """Home endpoint"""
    REQUEST_COUNT.labels(method='GET', endpoint='/', status=200).inc()
    return jsonify({
        'message': 'Welcome to AKS POC Application',
        'version': '1.0.0',
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/health')
@REQUEST_LATENCY.time()
def health():
    """Health check endpoint"""
    REQUEST_COUNT.labels(method='GET', endpoint='/health', status=200).inc()
    
    # Check database connectivity
    db_status = "healthy"
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('SELECT 1')
        cur.close()
        conn.close()
    except Exception as e:
        db_status = "unhealthy"
        logger.error(f"Health check failed: {e}")
    
    return jsonify({
        'status': 'healthy',
        'database': db_status,
        'timestamp': datetime.utcnow().isoformat()
    }), 200

@app.route('/api/users', methods=['GET', 'POST'])
@REQUEST_LATENCY.time()
def users():
    """Users endpoint - GET list users, POST create user"""
    try:
        if request.method == 'GET':
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute('SELECT id, name, email, created_at FROM users ORDER BY created_at DESC LIMIT 10')
            users = []
            for row in cur.fetchall():
                users.append({
                    'id': row[0],
                    'name': row[1],
                    'email': row[2],
                    'created_at': row[3].isoformat()
                })
            cur.close()
            conn.close()
            
            REQUEST_COUNT.labels(method='GET', endpoint='/api/users', status=200).inc()
            return jsonify({'users': users}), 200
        
        elif request.method == 'POST':
            data = request.get_json()
            if not data or 'name' not in data or 'email' not in data:
                REQUEST_COUNT.labels(method='POST', endpoint='/api/users', status=400).inc()
                return jsonify({'error': 'Name and email are required'}), 400
            
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute(
                'INSERT INTO users (name, email) VALUES (%s, %s) RETURNING id, name, email, created_at',
                (data['name'], data['email'])
            )
            user_data = cur.fetchone()
            conn.commit()
            cur.close()
            conn.close()
            
            REQUEST_COUNT.labels(method='POST', endpoint='/api/users', status=201).inc()
            return jsonify({
                'user': {
                    'id': user_data[0],
                    'name': user_data[1],
                    'email': user_data[2],
                    'created_at': user_data[3].isoformat()
                }
            }), 201
    
    except Exception as e:
        logger.error(f"Users endpoint error: {e}")
        REQUEST_COUNT.labels(method=request.method, endpoint='/api/users', status=500).inc()
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/users/<int:user_id>', methods=['GET', 'DELETE'])
@REQUEST_LATENCY.time()
def user_detail(user_id):
    """User detail endpoint"""
    try:
        if request.method == 'GET':
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute('SELECT id, name, email, created_at FROM users WHERE id = %s', (user_id,))
            user_data = cur.fetchone()
            cur.close()
            conn.close()
            
            if not user_data:
                REQUEST_COUNT.labels(method='GET', endpoint=f'/api/users/{user_id}', status=404).inc()
                return jsonify({'error': 'User not found'}), 404
            
            REQUEST_COUNT.labels(method='GET', endpoint=f'/api/users/{user_id}', status=200).inc()
            return jsonify({
                'user': {
                    'id': user_data[0],
                    'name': user_data[1],
                    'email': user_data[2],
                    'created_at': user_data[3].isoformat()
                }
            }), 200
        
        elif request.method == 'DELETE':
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute('DELETE FROM users WHERE id = %s', (user_id,))
            conn.commit()
            cur.close()
            conn.close()
            
            REQUEST_COUNT.labels(method='DELETE', endpoint=f'/api/users/{user_id}', status=200).inc()
            return jsonify({'message': 'User deleted successfully'}), 200
    
    except Exception as e:
        logger.error(f"User detail endpoint error: {e}")
        REQUEST_COUNT.labels(method=request.method, endpoint=f'/api/users/{user_id}', status=500).inc()
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/stats')
@REQUEST_LATENCY.time()
def stats():
    """Statistics endpoint"""
    REQUEST_COUNT.labels(method='GET', endpoint='/api/stats', status=200).inc()
    
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Get user count
        cur.execute('SELECT COUNT(*) FROM users')
        user_count = cur.fetchone()[0]
        
        # Get recent request count
        cur.execute('SELECT COUNT(*) FROM requests WHERE created_at > NOW() - INTERVAL \'1 hour\'')
        recent_requests = cur.fetchone()[0]
        
        cur.close()
        conn.close()
        
        return jsonify({
            'statistics': {
                'total_users': user_count,
                'recent_requests': recent_requests,
                'timestamp': datetime.utcnow().isoformat()
            }
        }), 200
    
    except Exception as e:
        logger.error(f"Stats endpoint error: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/metrics')
@REQUEST_LATENCY.time()
def metrics():
    """Prometheus metrics endpoint"""
    REQUEST_COUNT.labels(method='GET', endpoint='/metrics', status=200).inc()
    return generate_latest()

@app.errorhandler(404)
def not_found(error):
    """404 error handler"""
    REQUEST_COUNT.labels(method='GET', endpoint='not_found', status=404).inc()
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    """500 error handler"""
    REQUEST_COUNT.labels(method='GET', endpoint='internal_error', status=500).inc()
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    # Initialize database on startup
    try:
        initialize_database()
        logger.info("Application initialized successfully")
    except Exception as e:
        logger.error(f"Application initialization failed: {e}")
        logger.info("Starting without database connection")
    
    # Start metrics server
    start_http_server(8000)
    logger.info("Metrics server started on port 8000")
    
    # Start Flask app
    app.run(host='0.0.0.0', port=8080, debug=False)