# Waldo - Desktop Identification System

A comprehensive macOS steganographic identification system with transparent overlays, automatic logging, and MongoDB analytics. 

**"Where's Waldo?"** - Now you can find any desktop from a simple photo.

## Features

### 🖥️ Desktop Watermarking
- **Transparent Overlays**: Invisible watermarks embedded in real-time on all displays
- **Automatic System Detection**: Auto-detects username, machine UUID, and computer name
- **Hourly Refresh**: Watermarks update automatically with current timestamp
- **Multi-Display Support**: Works seamlessly across multiple monitors

### 🔍 Steganography
- **LSB (Least Significant Bit)** steganography for invisible watermarks
- **Photo Extraction**: Identify watermarks from cellphone photos of desktops
- **Robust Encoding**: Survives photo compression and scaling

### 📊 Centralized Logging
- **MongoDB Database**: Stores all watermark events and analytics
- **RESTful API**: Express.js server for real-time event logging  
- **Event Tracking**: Logs overlay start/stop, refreshes, and extractions
- **No Local Database**: Deprecated SQLite in favor of centralized API

## Quick Start

### 1. Start the API Server

```bash
cd api
npm install
cp .env.example .env
# Edit .env with your MongoDB connection
npm start
```

### 2. Build and Run Desktop Application

```bash
swift build
```

### 3. Start Transparent Overlay

```bash
# Start overlay with automatic watermarking
./.build/debug/waldo overlay start --daemon

# Check overlay status
./.build/debug/waldo overlay status --verbose

# Stop overlay
./.build/debug/waldo overlay stop
```

## Commands

### Overlay Management
```bash
# Start transparent overlay watermarking
waldo overlay start [--daemon] [--watermark "custom_text"]

# Stop overlay watermarking
waldo overlay stop

# Check overlay status and system info
waldo overlay status [--verbose]
```

### Traditional Screenshot Watermarking
```bash
# Create user (optional - auto-logged to API)
waldo setup --user-id "alice" --name "Alice Smith"

# Embed watermark in screenshot (auto-detects system user)
waldo embed --user-id "alice" --watermark "office_desk"

# Extract watermark from photo
waldo extract "/path/to/photo.jpg" --verbose

# Show current system user
waldo users
```

## API Endpoints

### Event Logging
- `POST /api/events` - Log watermark events
- `GET /api/events/user/:userId` - Get user events
- `GET /api/events/active-overlays` - Get active overlays
- `GET /api/events/search` - Search events

### Analytics
- `GET /api/analytics/dashboard` - Dashboard data
- `GET /api/analytics/trends` - Trend analysis
- `GET /api/analytics/top-users` - User activity
- `GET /api/analytics/machine-activity` - Machine statistics

## How It Works

### Transparent Overlay System
1. **Overlay Creation**: Creates invisible `NSWindow` at overlay level on each display
2. **Watermark Embedding**: Uses LSB steganography to embed user+machine+timestamp
3. **Hourly Refresh**: Updates watermark data every hour for temporal tracking
4. **API Logging**: Logs all events to MongoDB via REST API

### Watermark Format
```
username:computer-name:machine-uuid:timestamp
```
Example: `alice:Alices-MacBook-Pro:A1B2C3D4-E5F6:1703875200`

### Event Types
- `overlay_start` - Overlay watermarking started
- `overlay_stop` - Overlay watermarking stopped  
- `watermark_refresh` - Hourly watermark update
- `extraction` - Watermark detected in photo
- `screen_change` - Display configuration changed

## Configuration

### Environment Variables
```bash
# API Configuration
WALDO_API_URL=http://localhost:3000/api
WALDO_API_KEY=your-secure-api-key

# MongoDB Connection  
MONGODB_URI=mongodb://localhost:27017/waldo

# Server Settings
PORT=3000
NODE_ENV=production
```

### macOS Permissions
- **Screen Recording Permission**: Required for overlay windows
- Automatically requests permission on first run

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  macOS Client   │    │   Express API   │    │    MongoDB      │
│                 │    │                 │    │                 │
│ Overlay Windows │───▶│ Event Logging   │───▶│ Event Storage   │
│ System Info     │    │ Analytics       │    │ User Tracking   │
│ Steganography   │    │ RESTful Routes  │    │ Time Series     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Use Cases

### Corporate Desktop Identification
- Track employee desktop usage
- Identify leaked screenshots  
- Audit desktop access
- Security forensics

### Content Protection
- Watermark sensitive displays
- Trace screenshot origins
- Legal evidence collection
- IP protection

### System Monitoring
- Real-time desktop tracking
- Multi-machine analytics
- User behavior analysis
- Security event correlation

## Security Considerations

- **Invisible Watermarks**: Completely transparent to users
- **Minimal Performance Impact**: Lightweight overlay rendering
- **Centralized Storage**: All data stored securely in MongoDB
- **API Authentication**: Optional API key protection
- **Offline Resilience**: Works offline with retry queue
- **No Local Database**: Eliminates SQLite security concerns

## Database Schema

```javascript
{
  eventType: "overlay_start|overlay_stop|watermark_refresh|extraction",
  userId: String,
  username: String,
  computerName: String,
  machineUUID: String,
  watermarkData: String,
  timestamp: Date,
  metadata: Object,
  parsedWatermark: {
    username: String,
    computerName: String,
    machineUUID: String,
    timestamp: Number
  }
}
```

## Development

### Prerequisites
- macOS 13.0+
- Swift 5.9+
- Node.js 18+
- MongoDB 5.0+

### Building
```bash
# Swift application
swift build

# API server
cd api && npm install && npm start

# MongoDB (via Homebrew)
brew install mongodb-community && brew services start mongodb-community
```

### Testing
```bash
# Test overlay system
./.build/debug/waldo overlay start
# Take photo of desktop
./.build/debug/waldo extract photo.jpg

# Test API
curl -X POST localhost:3000/api/events \
  -H "Content-Type: application/json" \
  -d '{"eventType":"test","userId":"test_user",...}'
```

This system provides comprehensive desktop watermarking with enterprise-grade logging and analytics capabilities.