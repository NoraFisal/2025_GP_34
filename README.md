# SPARK

SPARK is a mobile esports Team Formation platform designed to support players and organizers through tournament management, player performance analytics, AI-powered recommendations add Chatbot.

The platform supports multiple esports titles, while the advanced team formation and win-rate prediction features are focused on League of Legends.

---

# GitHub Repository

https://github.com/NoraFisal/2026_GP_34

---

# Installation and Run Instructions

## 1. Clone the Repository

```bash
git clone https://github.com/NoraFisal/2026_GP_34.git
cd 2026_GP_34
```

---

## 2. Open the Project

Open the project using:

- Visual Studio Code
- Android Studio

---

## 3. Install Dependencies

Run:

```bash
flutter pub get
```

---

## 4. Download Required AI Model Files

Due to GitHub file size limitations, the AI model files are hosted separately on Google Drive.

Download the model files from:

```text
PUT_GOOGLE_DRIVE_MODEL_LINK_HERE
```

After downloading, place the files inside:

```text
assets/model/
```

---

## 5. API Keys Setup

Some features require external API keys. These keys are not permanently included because some APIs expire periodically or must be generated individually by the tester.

---

### Riot Games API Key (League of Legends)

This key is required for:

- Player linking
- Team formation
- Match statistics
- League of Legends performance features

Create a Riot API key from:

https://developer.riotgames.com/

Add the key in:

```text
lib/data/riot_link_server.dart
Line 14
```

⚠️ Riot development API keys expire every 24 hours and must be regenerated when expired.

---

### PUBG API Key

This key is required for PUBG player connection and player data retrieval.

Create a PUBG API key from:

https://developer.pubg.com/

Add the key in:

```text
lib/pages/player/connect_game_page.dart
Line 60
```

---

### Chatbot API Key

This key is required for the AI chatbot feature used in player reports.

Create an API key from OpenRouter:

https://openrouter.ai/

Add the key in:

```text
lib/pages/player/report_chatbot_page.dart
Line 25
```

---

### Dota 2

Dota 2 integration does not require API key regeneration.

---

## 6. Run the Application

After completing the API key setup and placing the model files in the correct folder, the application can be launched by opening the project in Visual Studio Code or Android Studio, connecting an Android device or emulator, and running:

```bash
flutter pub get
flutter run
```

The app can also be run directly from Visual Studio Code by selecting the connected device and pressing the Run button.

---

# Testing Information

To test the application properly:

1. Run the application on an Android emulator or Android device.
2. Create a new account or log in using Firebase Authentication.
3. Verify the email if email verification is enabled.
4. Connect game accounts through the player profile page.
5. Test tournaments, teams, reports, lineup recommendations, and chatbot features.

---

# Additional Notes

- Internet connection is required for Firebase services, APIs, and chatbot functionality.
- Firebase Authentication, Firestore, and Storage are used as backend services.
- Some features may not function correctly if required API keys are missing or expired.
- Riot API keys must be updated regularly because development keys expire every 24 hours.
- AI model files are stored separately because GitHub does not allow files larger than 100 MB.

---

# Main Technologies

- Flutter
- Dart
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Riot Games API
- PUBG API
- OpenDota API
- OpenRouter API
- Python
- Machine Learning Models

---

# Project Features

SPARK includes:

- User registration and login
- Player and organizer profiles
- Tournament creation and management
- Team creation and management
- Player performance reports
- AI-powered team formation
- Win-rate prediction
- Tournament recommendations
- Chatbot support for report explanation
- Search and filtering system
- Real-time esports data integration
