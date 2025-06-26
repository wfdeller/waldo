const express = require('express');
const Event = require('../models/Event');

const router = express.Router();

// GET /api/analytics/dashboard - Get dashboard analytics
router.get('/dashboard', async (req, res) => {
  try {
    const timeRange = req.query.timeRange || '24h';
    
    // Calculate time range
    const now = new Date();
    let startDate;
    
    switch (timeRange) {
      case '1h':
        startDate = new Date(now.getTime() - 60 * 60 * 1000);
        break;
      case '24h':
        startDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
        break;
      case '7d':
        startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        break;
      case '30d':
        startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
        break;
      default:
        startDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    }

    // Parallel queries for dashboard data
    const [
      totalEvents,
      recentEvents,
      eventsByType,
      uniqueUsers,
      uniqueMachines,
      activeOverlays,
      extractionEvents,
      hourlyActivity
    ] = await Promise.all([
      // Total events in time range
      Event.countDocuments({
        timestamp: { $gte: startDate }
      }),
      
      // Recent events
      Event.find({
        timestamp: { $gte: startDate }
      })
        .sort({ timestamp: -1 })
        .limit(10),
      
      // Events by type
      Event.aggregate([
        {
          $match: { timestamp: { $gte: startDate } }
        },
        {
          $group: {
            _id: '$eventType',
            count: { $sum: 1 }
          }
        }
      ]),
      
      // Unique users
      Event.distinct('userId', {
        timestamp: { $gte: startDate }
      }),
      
      // Unique machines
      Event.distinct('machineUUID', {
        timestamp: { $gte: startDate }
      }),
      
      // Active overlays
      Event.getActiveOverlays(),
      
      // Extraction events (watermark detections)
      Event.find({
        eventType: 'extraction',
        timestamp: { $gte: startDate }
      })
        .sort({ timestamp: -1 })
        .limit(20),
      
      // Hourly activity
      Event.aggregate([
        {
          $match: { timestamp: { $gte: startDate } }
        },
        {
          $group: {
            _id: {
              $dateToString: {
                format: '%Y-%m-%d %H:00',
                date: '$timestamp'
              }
            },
            count: { $sum: 1 }
          }
        },
        {
          $sort: { '_id': 1 }
        }
      ])
    ]);

    res.json({
      success: true,
      data: {
        timeRange,
        summary: {
          totalEvents,
          uniqueUsers: uniqueUsers.length,
          uniqueMachines: uniqueMachines.length,
          activeOverlays: activeOverlays.length,
          extractionEvents: extractionEvents.length
        },
        eventsByType: eventsByType.reduce((acc, item) => {
          acc[item._id] = item.count;
          return acc;
        }, {}),
        recentEvents: recentEvents.map(event => ({
          _id: event._id,
          eventType: event.eventType,
          username: event.username,
          computerName: event.computerName,
          timestamp: event.timestamp
        })),
        activeOverlays: activeOverlays.map(overlay => ({
          username: overlay.username,
          computerName: overlay.computerName,
          machineUUID: overlay.machineUUID,
          startTime: overlay.timestamp
        })),
        extractionEvents: extractionEvents.map(event => ({
          _id: event._id,
          username: event.username,
          computerName: event.computerName,
          watermarkData: event.watermarkData,
          timestamp: event.timestamp,
          metadata: event.metadata
        })),
        hourlyActivity: hourlyActivity.map(item => ({
          hour: item._id,
          count: item.count
        }))
      }
    });

  } catch (error) {
    console.error('Error fetching dashboard analytics:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to fetch dashboard analytics'
    });
  }
});

// GET /api/analytics/trends - Get trend data
router.get('/trends', async (req, res) => {
  try {
    const days = parseInt(req.query.days) || 7;
    const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

    const trends = await Event.aggregate([
      {
        $match: { timestamp: { $gte: startDate } }
      },
      {
        $group: {
          _id: {
            date: {
              $dateToString: {
                format: '%Y-%m-%d',
                date: '$timestamp'
              }
            },
            eventType: '$eventType'
          },
          count: { $sum: 1 }
        }
      },
      {
        $group: {
          _id: '$_id.date',
          events: {
            $push: {
              eventType: '$_id.eventType',
              count: '$count'
            }
          },
          totalCount: { $sum: '$count' }
        }
      },
      {
        $sort: { '_id': 1 }
      }
    ]);

    res.json({
      success: true,
      data: {
        days,
        trends: trends.map(day => ({
          date: day._id,
          totalEvents: day.totalCount,
          eventBreakdown: day.events.reduce((acc, event) => {
            acc[event.eventType] = event.count;
            return acc;
          }, {})
        }))
      }
    });

  } catch (error) {
    console.error('Error fetching trends:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to fetch trends'
    });
  }
});

// GET /api/analytics/top-users - Get top users by activity
router.get('/top-users', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const days = parseInt(req.query.days) || 7;
    const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

    const topUsers = await Event.aggregate([
      {
        $match: { timestamp: { $gte: startDate } }
      },
      {
        $group: {
          _id: {
            userId: '$userId',
            username: '$username'
          },
          totalEvents: { $sum: 1 },
          lastActivity: { $max: '$timestamp' },
          eventTypes: { $addToSet: '$eventType' },
          machines: { $addToSet: '$machineUUID' }
        }
      },
      {
        $sort: { totalEvents: -1 }
      },
      {
        $limit: limit
      }
    ]);

    res.json({
      success: true,
      data: {
        timeRange: `${days} days`,
        topUsers: topUsers.map(user => ({
          userId: user._id.userId,
          username: user._id.username,
          totalEvents: user.totalEvents,
          lastActivity: user.lastActivity,
          uniqueEventTypes: user.eventTypes.length,
          uniqueMachines: user.machines.length
        }))
      }
    });

  } catch (error) {
    console.error('Error fetching top users:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to fetch top users'
    });
  }
});

// GET /api/analytics/machine-activity - Get machine activity statistics
router.get('/machine-activity', async (req, res) => {
  try {
    const days = parseInt(req.query.days) || 7;
    const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

    const machineActivity = await Event.aggregate([
      {
        $match: { timestamp: { $gte: startDate } }
      },
      {
        $group: {
          _id: {
            machineUUID: '$machineUUID',
            computerName: '$computerName',
            username: '$username'
          },
          totalEvents: { $sum: 1 },
          firstActivity: { $min: '$timestamp' },
          lastActivity: { $max: '$timestamp' },
          eventTypes: { $addToSet: '$eventType' }
        }
      },
      {
        $sort: { totalEvents: -1 }
      }
    ]);

    res.json({
      success: true,
      data: {
        timeRange: `${days} days`,
        machines: machineActivity.map(machine => ({
          machineUUID: machine._id.machineUUID,
          computerName: machine._id.computerName,
          username: machine._id.username,
          totalEvents: machine.totalEvents,
          firstActivity: machine.firstActivity,
          lastActivity: machine.lastActivity,
          eventTypes: machine.eventTypes
        }))
      }
    });

  } catch (error) {
    console.error('Error fetching machine activity:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to fetch machine activity'
    });
  }
});

module.exports = router;