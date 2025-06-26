const express = require('express');
const { body } = require('express-validator');
const eventController = require('../controllers/eventController');

const router = express.Router();

// Validation middleware for event creation
const validateEvent = [
  body('eventType')
    .isIn(['overlay_start', 'overlay_stop', 'watermark_refresh', 'extraction', 'screen_change', 'embed', 'user_create'])
    .withMessage('Invalid event type'),
  
  body('userId')
    .notEmpty()
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('User ID is required and must be between 1-100 characters'),
  
  body('username')
    .notEmpty()
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('Username is required and must be between 1-100 characters'),
  
  body('computerName')
    .notEmpty()
    .trim()
    .isLength({ min: 1, max: 200 })
    .withMessage('Computer name is required and must be between 1-200 characters'),
  
  body('machineUUID')
    .notEmpty()
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('Machine UUID is required and must be between 1-100 characters'),
  
  body('watermarkData')
    .notEmpty()
    .trim()
    .isLength({ min: 1, max: 1000 })
    .withMessage('Watermark data is required and must be between 1-1000 characters'),
  
  body('timestamp')
    .optional()
    .isNumeric()
    .withMessage('Timestamp must be a number'),
  
  body('osVersion')
    .optional()
    .trim()
    .isLength({ max: 100 })
    .withMessage('OS version must be less than 100 characters'),
  
  body('hostname')
    .optional()
    .trim()
    .isLength({ max: 200 })
    .withMessage('Hostname must be less than 200 characters'),
  
  body('metadata')
    .optional()
    .isObject()
    .withMessage('Metadata must be an object')
];

// Routes

// POST /api/events - Create a new event
router.post('/', validateEvent, eventController.createEvent);

// GET /api/events/search - Search events
router.get('/search', eventController.searchEvents);

// GET /api/events/active-overlays - Get currently active overlays
router.get('/active-overlays', eventController.getActiveOverlays);

// GET /api/events/user/:userId - Get events by user ID
router.get('/user/:userId', eventController.getEventsByUser);

// GET /api/events/user/:userId/stats - Get user statistics
router.get('/user/:userId/stats', eventController.getUserStats);

// GET /api/events/machine/:machineUUID - Get events by machine UUID
router.get('/machine/:machineUUID', eventController.getEventsByMachine);

// GET /api/events/timerange - Get events by time range
router.get('/timerange', eventController.getEventsByTimeRange);

module.exports = router;