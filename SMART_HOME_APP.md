# Smart Home Community App

A Flutter-based smart home control application designed based on Figma specifications, featuring a modern dark theme UI and comprehensive device management capabilities.

## 🏠 Features

### Core Functionality
- **Device Control Dashboard** - Central hub for managing all smart home devices
- **Real-time Device Status** - Live monitoring of device states and values
- **Smart Search & Filtering** - Find devices quickly by name or category
- **Energy Cost Tracking** - Monitor monthly energy consumption and costs
- **Quick Actions** - One-tap controls for common scenarios (All Lights Off, Away Mode)

### Device Categories
- **Lighting** - Smart bulbs, switches, and ambient lighting
- **Climate** - Thermostats, AC units, and temperature control
- **Security** - Door locks, security systems, and monitoring
- **Entertainment** - Smart TVs, speakers, and media devices

### User Interface
- **Dark Theme Design** - Modern, eye-friendly interface based on Figma design
- **Responsive Layout** - Optimized for mobile and tablet devices
- **Intuitive Navigation** - Bottom navigation with clear iconography
- **Interactive Components** - Smooth animations and haptic feedback

## 🎨 Design System

### Colors (Based on Figma Analysis)
- **Primary**: Blue (#2196F3) - Main accent color
- **Secondary**: Teal (#03DAC6) - Secondary actions
- **Background**: Dark Gray (#121212) - Main background
- **Surface**: Charcoal (#1E1E1E) - Card backgrounds
- **Card**: Dark Gray (#2C2C2C) - Component backgrounds
- **Text Primary**: White (#FFFFFF) - Main text
- **Text Secondary**: Light Gray (#B3B3B3) - Secondary text
- **Accent**: Green (#4CAF50) - Success states

### Typography
- **Font Family**: Inter (fallback from PingFang SC in Figma)
- **Font Weights**: 400 (Regular), 500 (Medium), 600 (Semibold)
- **Font Sizes**: 12px - 32px with proper line heights
- **Letter Spacing**: -0.41px for body text (matching Figma specs)

### Components
- **Border Radius**: 8px (small), 12px (medium), 16px (large)
- **Padding**: 8px, 16px, 24px, 32px system
- **Shadows**: Subtle elevation with dark theme compatibility

## 📱 Screens

### 1. Home Dashboard (`HomeScreen`)
- Welcome section with personalized greeting
- Energy cost display showing monthly expenses ($6,204 from Figma)
- Smart input field for device search ("Type something" placeholder)
- Device control grid with quick toggles
- Quick action buttons for common scenarios

### 2. All Devices (`DevicesScreen`)
- Comprehensive device listing with search functionality
- Category filtering (All, Lighting, Climate, Security, Entertainment)
- Device detail modal with settings and automation options
- Add new device functionality

### 3. Profile (`ProfileScreen`)
- User profile header with avatar
- Home information cards (devices, rooms, energy saved, automations)
- Settings section (notifications, security, appearance)
- Account management (personal info, backup)
- Support section (help center, feedback, sign out)

### 4. Scenes (`ScenesScreen`)
- Smart automation scenes with pre-built scenarios
- Active scenes monitoring and control
- Scene cards with color-coded categories
- Manual, scheduled, and location-based triggers
- Scene details with device lists and controls
- **Add New Scene** functionality with 5-step wizard

### 5. Add Scene (`AddSceneScreen`)
- Multi-step scene creation wizard (5 steps)
- Basic information input (name, description)
- Icon and color customization (24 icons, 8 colors)
- Trigger configuration (Manual, Time, Location, Sensor)
- Device selection with category filtering
- Review and confirmation before creation

## 🔧 Technical Architecture

### Project Structure
```
lib/
├── main.dart                 # App entry point
├── theme/
│   └── app_theme.dart       # Design system and theme configuration
├── screens/
│   ├── home_screen.dart     # Main dashboard
│   └── devices_screen.dart  # Device management
├── widgets/
│   ├── device_card.dart     # Reusable device control component
│   ├── smart_input_field.dart # Custom input with Figma styling
│   └── price_display.dart   # Currency formatting component
└── services/
    └── figma_service.dart   # Figma API integration
```

### Key Components

#### `DeviceCard`
- Toggle switch for device control
- Status indicators (Online/Offline)
- Value display for sensors (temperature, etc.)
- Tap gesture for detailed view
- Visual feedback for device states

#### `SmartInputField`
- Focus state management with color changes
- Prefix/suffix icon support
- Figma-compliant styling and typography
- Responsive design for different screen sizes

#### `PriceDisplay`
- Currency formatting with proper comma separation
- Flexible styling options
- Support for cents display
- Responsive text sizing

## 🎯 Figma Integration

### Design Source
- **File**: Smart Home Community
- **URL**: `https://www.figma.com/design/tUUu8oFzoDWuRX1Fxvnf1e/Smart-Home--Community-?node-id=0-6244`
- **Token**: `YOUR_FIGMA_PERSONAL_ACCESS_TOKEN` (replace with your actual token)

### Extracted Design Elements
- **Dark keyboard components** - Translated to input fields
- **Typography specifications** - PingFang SC font family and sizing
- **Color palette** - Dark theme with blue accents
- **Component dimensions** - 375px mobile width, proper spacing
- **Price display format** - $6,204 formatting pattern

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.8.1+)
- Dart SDK
- Chrome/Edge browser for web testing

### Installation
1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run -d chrome
   ```

### Building
- **Web**: `flutter build web`
- **Android**: `flutter build apk`
- **iOS**: `flutter build ios`

## 🔮 Future Enhancements

### Planned Features
- **Analytics Dashboard** - Energy usage charts and insights
- **User Profile** - Settings and preferences management
- **Automation Rules** - Schedule-based device control
- **Voice Control** - Integration with voice assistants
- **Real-time Notifications** - Device alerts and status updates
- **Multi-home Support** - Manage multiple properties

### Technical Improvements
- **State Management** - Implement Provider/Riverpod for complex state
- **Local Storage** - Cache device states and user preferences
- **API Integration** - Connect to real smart home platforms
- **Offline Support** - Local device control capabilities
- **Performance Optimization** - Lazy loading and caching strategies

## 📄 License

This project is created for demonstration purposes based on Figma design specifications.

## 🤝 Contributing

This is a demonstration project showcasing Flutter development based on Figma designs. The implementation focuses on:
- Pixel-perfect design translation from Figma
- Modern Flutter best practices
- Responsive and accessible UI components
- Clean architecture and code organization

The app successfully translates the Figma design into a functional Flutter application with proper theming, component structure, and user interaction patterns.
