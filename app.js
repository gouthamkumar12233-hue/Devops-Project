const express = require('express');
const morgan = require('morgan');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || 'development';

// Middleware
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.static('public'));

// Health check endpoint for load balancer
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Ready endpoint
app.get('/ready', (req, res) => {
  res.status(200).json({
    ready: true,
    environment: NODE_ENV
  });
});

// API Routes
app.get('/api/v1/status', (req, res) => {
  res.json({
    message: 'API is running',
    version: '1.0.0',
    environment: NODE_ENV,
    timestamp: new Date().toISOString()
  });
});

// Sample endpoint with database call (example)
app.get('/api/v1/data', async (req, res) => {
  try {
    // Example: fetch data from database
    // const data = await db.query('SELECT * FROM users');
    
    res.json({
      message: 'Data endpoint',
      data: []
    });
  } catch (error) {
    console.error('Error fetching data:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not found',
    path: req.path
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(err.status || 500).json({
    error: err.message || 'Internal server error',
    environment: NODE_ENV
  });
});

// Start server
const server = app.listen(PORT, () => {
  console.log(`[${NODE_ENV}] Server running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

module.exports = app;
