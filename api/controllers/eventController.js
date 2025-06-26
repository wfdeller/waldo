const Event = require('../models/Event');
const { validationResult } = require('express-validator');

// Create a new event
exports.createEvent = async (req, res) => {
  try {
    // Check for validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation failed',
        details: errors.array()
      });
    }

    // Extract IP address and user agent
    const ipAddress = req.ip || req.connection.remoteAddress || req.headers['x-forwarded-for'];
    const userAgent = req.headers['user-agent'];

    // Create event with request data
    const eventData = {
      ...req.body,
      ipAddress,
      userAgent,
      timestamp: new Date(req.body.timestamp * 1000) || new Date()
    };

    const event = new Event(eventData);
    await event.save();

    res.status(201).json({
      success: true,
      message: 'Event logged successfully',
      data: event.toPublicJSON()
    });

  } catch (error) {
    console.error('Error creating event:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to create event'
    });
  }
};

// Get events by user ID
exports.getEventsByUser = async (req, res) => {
  try {
    const { userId } = req.params;
    const limit = parseInt(req.query.limit) || 100;
    const offset = parseInt(req.query.offset) || 0;
    const eventType = req.query.eventType;

    let query = { userId };
    if (eventType) {
      query.eventType = eventType;
    }

    const events = await Event.find(query)
      .sort({ timestamp: -1 })
      .limit(Math.min(limit, 1000)) // Cap at 1000
      .skip(offset);

    const total = await Event.countDocuments(query);

    res.json({
      success: true,
      data: events.map(event => event.toPublicJSON()),
      pagination: {
        total,
        limit,
        offset,
        hasMore: offset + events.length < total
      }
    });

  } catch (error) {
    console.error('Error fetching events by user:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to fetch events'
    });
  }
};

// Get events by machine UUID
exports.getEventsByMachine = async (req, res) => {
  try {
    const { machineUUID } = req.params;
    const limit = parseInt(req.query.limit) || 100;
    const offset = parseInt(req.query.offset) || 0;

    const events = await Event.findByMachine(machineUUID, limit)
      .skip(offset);

    const total = await Event.countDocuments({ machineUUID });

    res.json({
      success: true,
      data: events.map(event => event.toPublicJSON()),
      pagination: {
        total,
        limit,
        offset,
        hasMore: offset + events.length < total
      }
    });

  } catch (error) {
    console.error('Error fetching events by machine:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to fetch events'
    });
  }
};

// Get events by time range
exports.getEventsByTimeRange = async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    const limit = parseInt(req.query.limit) || 1000;
    const eventType = req.query.eventType;

    if (!startDate || !endDate) {
      return res.status(400).json({
        error: 'Bad request',
        message: 'startDate and endDate are required'
      });
    }

    const start = new Date(startDate);
    const end = new Date(endDate);

    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      return res.status(400).json({
        error: 'Bad request',
        message: 'Invalid date format'
      });
    }

    let query = {
      timestamp: { $gte: start, $lte: end }
    };

    if (eventType) {
      query.eventType = eventType;
    }

    const events = await Event.find(query)
      .sort({ timestamp: -1 })
      .limit(Math.min(limit, 5000)); // Cap at 5000 for time range queries

    res.json({
      success: true,
      data: events.map(event => event.toPublicJSON()),
      query: {
        startDate: start.toISOString(),
        endDate: end.toISOString(),
        eventType: eventType || 'all',
        count: events.length
      }
    });

  } catch (error) {
    console.error('Error fetching events by time range:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to fetch events'
    });
  }
};

// Get active overlays
exports.getActiveOverlays = async (req, res) => {
  try {
    const activeOverlays = await Event.getActiveOverlays();

    res.json({
      success: true,
      data: activeOverlays.map(event => event.toPublicJSON ? event.toPublicJSON() : event),
      count: activeOverlays.length
    });

  } catch (error) {
    console.error('Error fetching active overlays:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to fetch active overlays'
    });
  }
};

// Get user statistics
exports.getUserStats = async (req, res) => {
  try {
    const { userId } = req.params;

    const stats = await Event.getUserStats(userId);
    const totalEvents = await Event.countDocuments({ userId });
    const firstEvent = await Event.findOne({ userId }).sort({ timestamp: 1 });
    const lastEvent = await Event.findOne({ userId }).sort({ timestamp: -1 });

    res.json({
      success: true,
      data: {
        userId,
        totalEvents,
        firstEvent: firstEvent?.timestamp,
        lastEvent: lastEvent?.timestamp,
        eventBreakdown: stats.reduce((acc, stat) => {
          acc[stat._id] = {
            count: stat.count,
            lastEvent: stat.lastEvent
          };
          return acc;
        }, {})
      }
    });

  } catch (error) {
    console.error('Error fetching user stats:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to fetch user statistics'
    });
  }
};

// Search events
exports.searchEvents = async (req, res) => {
  try {
    const { q, eventType, userId, machineUUID } = req.query;
    const limit = parseInt(req.query.limit) || 100;
    const offset = parseInt(req.query.offset) || 0;

    let query = {};

    if (q) {
      query.$or = [
        { username: { $regex: q, $options: 'i' } },
        { computerName: { $regex: q, $options: 'i' } },
        { watermarkData: { $regex: q, $options: 'i' } }
      ];
    }

    if (eventType) query.eventType = eventType;
    if (userId) query.userId = userId;
    if (machineUUID) query.machineUUID = machineUUID;

    const events = await Event.find(query)
      .sort({ timestamp: -1 })
      .limit(Math.min(limit, 1000))
      .skip(offset);

    const total = await Event.countDocuments(query);

    res.json({
      success: true,
      data: events.map(event => event.toPublicJSON()),
      pagination: {
        total,
        limit,
        offset,
        hasMore: offset + events.length < total
      },
      query: req.query
    });

  } catch (error) {
    console.error('Error searching events:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to search events'
    });
  }
};