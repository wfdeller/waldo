const mongoose = require('mongoose');

const eventSchema = new mongoose.Schema({
  eventType: {
    type: String,
    required: true,
    enum: [
      'overlay_start',
      'overlay_stop', 
      'watermark_refresh',
      'extraction',
      'screen_change',
      'embed',
      'user_create'
    ],
    index: true
  },
  
  userId: {
    type: String,
    required: true,
    trim: true,
    index: true
  },
  
  username: {
    type: String,
    required: true,
    trim: true
  },
  
  computerName: {
    type: String,
    required: true,
    trim: true
  },
  
  machineUUID: {
    type: String,
    required: true,
    trim: true,
    index: true
  },
  
  watermarkData: {
    type: String,
    required: true
  },
  
  timestamp: {
    type: Date,
    default: Date.now,
    index: true
  },
  
  ipAddress: {
    type: String,
    trim: true
  },
  
  userAgent: {
    type: String,
    trim: true
  },
  
  osVersion: {
    type: String,
    trim: true
  },
  
  hostname: {
    type: String,
    trim: true
  },
  
  metadata: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
  },
  
  // Parsed watermark components for easier querying
  parsedWatermark: {
    username: String,
    computerName: String,
    machineUUID: String,
    timestamp: Number
  }
}, {
  timestamps: true,
  collection: 'events'
});

// Indexes for efficient querying
eventSchema.index({ userId: 1, timestamp: -1 });
eventSchema.index({ machineUUID: 1, timestamp: -1 });
eventSchema.index({ eventType: 1, timestamp: -1 });
eventSchema.index({ 'parsedWatermark.timestamp': 1 });

// TTL index to automatically delete old events (optional)
// Uncomment to enable automatic deletion after 1 year
// eventSchema.index({ timestamp: 1 }, { expireAfterSeconds: 365 * 24 * 60 * 60 });

// Pre-save middleware to parse watermark data
eventSchema.pre('save', function(next) {
  if (this.watermarkData && this.isModified('watermarkData')) {
    const parts = this.watermarkData.split(':');
    if (parts.length >= 4) {
      this.parsedWatermark = {
        username: parts[0] || null,
        computerName: parts[1] || null,
        machineUUID: parts[2] || null,
        timestamp: parseInt(parts[3]) || null
      };
    }
  }
  next();
});

// Static methods for common queries
eventSchema.statics.findByUser = function(userId, limit = 100) {
  return this.find({ userId })
    .sort({ timestamp: -1 })
    .limit(limit);
};

eventSchema.statics.findByMachine = function(machineUUID, limit = 100) {
  return this.find({ machineUUID })
    .sort({ timestamp: -1 })
    .limit(limit);
};

eventSchema.statics.findByEventType = function(eventType, limit = 100) {
  return this.find({ eventType })
    .sort({ timestamp: -1 })
    .limit(limit);
};

eventSchema.statics.findByTimeRange = function(startDate, endDate, limit = 1000) {
  return this.find({
    timestamp: {
      $gte: startDate,
      $lte: endDate
    }
  })
    .sort({ timestamp: -1 })
    .limit(limit);
};

eventSchema.statics.getActiveOverlays = function() {
  return this.aggregate([
    {
      $match: {
        eventType: { $in: ['overlay_start', 'overlay_stop'] }
      }
    },
    {
      $sort: { timestamp: -1 }
    },
    {
      $group: {
        _id: '$machineUUID',
        lastEvent: { $first: '$$ROOT' }
      }
    },
    {
      $match: {
        'lastEvent.eventType': 'overlay_start'
      }
    },
    {
      $replaceRoot: { newRoot: '$lastEvent' }
    }
  ]);
};

eventSchema.statics.getUserStats = function(userId) {
  return this.aggregate([
    { $match: { userId } },
    {
      $group: {
        _id: '$eventType',
        count: { $sum: 1 },
        lastEvent: { $max: '$timestamp' }
      }
    }
  ]);
};

// Instance methods
eventSchema.methods.toPublicJSON = function() {
  const obj = this.toObject();
  delete obj.__v;
  return obj;
};

const Event = mongoose.model('Event', eventSchema);

module.exports = Event;