# 📱 Smart Task Mobile App

A cross-platform mobile interface for the Smart Task system, built with **Flutter**. This app manages task visualization, user input, and communication with the Python backend.

## 🛠 Prerequisites

* [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.0+)
* Android Studio / VS Code with Flutter extensions
* Android Emulator or Physical Device


## 🚀 Setup & Installation

### 1. Install Dependencies
Navigate to the mobile directory and fetch the required packages:
cd mobile
flutter pub get


### 2. Environment Configuration
This app uses a secure .env file for API configuration.
* Navigate to mobile/assets/.
* Create a file named .env.
* Add your backend connection details:
# mobile/assets/.env
# Use 10.0.2.2 for Android Emulator, localhost for iOS simulator
API_BASE_URL=http://10.0.2.2:8000
API_KEY=your_secure_api_key


## 📱 Running the App

### Development Mode
To run the app with hot-reload enabled:
flutter run

## Testing
To run unit and widget tests:
flutter test

## 📦 Building for Production
To generate a release APK for Android:
flutter build apk --release

## Output location: build/app/outputs/flutter-apk/app-release.apk