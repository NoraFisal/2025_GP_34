# SPARK – AI Integrated Esports Platform

## Overview
SPARK is an AI-powered esports Team Formation platform designed to help players build balanced teams, analyze performance, manage tournaments, and communicate with teammates through a mobile application.

The platform mainly focuses on League of Legends team formation and win-rate prediction using AI models, while also supporting other games such as PUBG and Dota 2.

---

# GitHub Repository

Repository Link:

https://github.com/NoraFisal/2025_GP_34

---

# README Information

This README includes:
- Installation and run instructions
- Additional testing information
- API configuration instructions
- GitHub repository link

---

# Important Note Before Running the Project

Some large files such as AI model files were not uploaded directly to GitHub because they exceed GitHub file size limitations.

These files are required for the application to work correctly.

Download the required files from Google Drive and place them inside the project before running the application.

Google Drive Folder:

https://drive.google.com/drive/folders/198lT-YV4zGBjbtdEf6dAOCV-Fo0by5zW?usp=drive_link

---

# Project Requirements

Before running the project, install the following:

- Flutter SDK
- Android Studio OR VS Code
- Dart SDK
- Android Emulator OR Android Tablet/Phone

Recommended Flutter version:
Flutter 3.x

---

# Installation and Run Instructions

## Step 1 – Clone the Repository

```bash
git clone https://github.com/NoraFisal/2025_GP_34.git
```

OR download the ZIP file manually from GitHub.

---

## Step 2 – Download Missing Large Files

Download the missing large files from the Google Drive folder:

https://drive.google.com/drive/folders/198lT-YV4zGBjbtdEf6dAOCV-Fo0by5zW?usp=drive_link

After downloading:
- Extract the files if needed
- Place them inside the correct folders in the project directory
- Replace any missing files

These files mainly include:
- AI model files
- Large assets not included in GitHub

Without these files, some AI features may not work correctly.

---

## Step 3 – Open the Project

Open the project folder using:
- VS Code
OR
- Android Studio

---

## Step 4 – Install Dependencies

Run:

```bash
flutter pub get
```

---

# API Keys Configuration

The project requires external API keys for some features.

---

## Riot API Key (League of Legends)

Used for:
- Player linking
- Match data
- Team formation features

Create Riot API Key from:

https://developer.riotgames.com/

Place the API key in:

```text
lib/data/riot_link_server.dart
```

Line:

```text
14
```

Replace the existing key with your own Riot API key.

Important:
- Riot development keys expire every 24 hours
- The key must be regenerated manually when expired

---

## PUBG API Key

Used for PUBG player connection and stats.

Create PUBG API Key from:

https://developer.pubg.com/

Place the API key in:

```text
lib/pages/player_connect_game_page.dart
```

Line:

```text
60
```

Replace the existing PUBG API key with your own key.

---

## Chatbot API Key

Used for the AI chatbot inside player reports.

Create API key from:

https://openrouter.ai/

Place the API key in:

```text
lib/pages/player_report_chatbot_page.dart
```

Line:

```text
25
```

Replace the existing chatbot API key with your own key.

---

# Step 5 – Run the Application

Connect an Android device OR open an emulator.

Then run:

```bash
flutter run
```

---

# APK Executable File

The executable APK file is included separately in:

```text
34_SPARK_Executable
```

The APK can be installed directly on Android devices without using an emulator.

---

# Additional Testing Information

## Firebase Authentication

The application uses Firebase Authentication for:
- Login
- Registration
- Email verification

Internet connection is required for authentication features.

---

## Supported Features

- AI Team Formation
- Win Rate Prediction
- Tournament Management
- Team Chat
- Performance Reports
- Riot Account Linking
- PUBG Player Linking
- AI Chatbot
- Explore Teams
- Player Profiles

---

# Notes

- Some APIs may stop working if the API key expires
- Riot API development keys expire every 24 hours
- Internet connection is required
- AI features depend on downloaded model files from Google Drive

---


# Authors

SPARK Graduation Project Team

- Nora Albyahi
- Mariam Alahmed
- Raghad Al-Dajani
- Aljawharah Al-Howidy

King Saud University  
College of Computer and Information Sciences  
Information Technology Department
