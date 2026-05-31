import unittest
import json
from app import app

class TestFlaskApp(unittest.TestCase):
    
    def setUp(self):
        self.app = app.test_client()
        self.app.testing = True
    
    def test_index(self):
        response = self.app.get('/')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertIn('message', data)
    
    def test_health(self):
        response = self.app.get('/health')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['status'], 'healthy')
    
    def test_metrics(self):
        response = self.app.get('/metrics')
        self.assertEqual(response.status_code, 200)
    
    def test_404(self):
        response = self.app.get('/nonexistent')
        self.assertEqual(response.status_code, 404)
    
    def test_users_get(self):
        response = self.app.get('/api/users')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertIn('users', data)

if __name__ == '__main__':
    unittest.main()