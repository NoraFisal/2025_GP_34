<p align="center">
  <img src="SPARK_Logo.png" width="180">
</p>

<h1 align="center">SPARK – Esports AI Platform</h1>

---

## Overview

SPARK is an AI-powered esports platform designed to help Saudi players, teams, and organizers connect, form professional teams, and analyze team performance using machine-learning insights.

The platform predicts team win probability, generates the top 3 optimal lineups, and provides a clean, user-friendly mobile app experience built with Flutter and Firebase.

This repository contains:
- Mobile app source code  
- AI model integration files  
- Project documentation  
- Sprint-1 deliverables  

---

## Project Goal

To provide an intelligent esports environment that:

- Helps players showcase skills professionally  
- Helps teams form optimal lineups  
- Supports organizers in tournaments  
- Predicts team win probability using AI  
- Enhances the Saudi esports ecosystem aligned with Vision 2030  

---

## Technologies Used

### Frontend
- Flutter (Dart)

### Backend
- Firebase Authentication  
- Firebase Firestore  
- Firebase Storage  

### AI & Data
- Python  
- Pandas  
- NumPy  
- Scikit-Learn (Random Forest Model)  
- Riot Games API  
- Kaggle Datasets  

### Design & Management
- Figma  
- Jira  
- GitHub  

---

# SPARK – Launching Instructions

Follow these steps to set up and run the project correctly on your machine.

---

## 1. Clone the Repository

```bash
git clone https://github.com/NoraFisal/2025_GP_34.git
```

---

## 2. Navigate to the Project Folder

```bash
cd 2025_GP_34
```

---

## 3. Install Flutter Dependencies

```bash
flutter pub get
```

---

## 4. Download Required ML Model Files

GitHub does NOT include the machine-learning model files because they exceed GitHub’s file size limit.

Download the required model files from Google Drive:

Model Files:
https://drive.google.com/drive/folders/1v3Zo-baUsxC8qw4N_H9L36EYDMnDUK2G

After downloading, place the files inside:

```text
assets/model/
```

Required files:
- random_forest_v5.json  
- feature_means_v5.json  
- feature_cols_v5.txt  

Then run again:

```bash
flutter pub get
```

---

## 5. Riot API Key

To run SPARK, you must generate your own Riot API Key.

### Step 1 — Create a Riot Developer Account

Go to:
https://developer.riotgames.com/

Click:
- Sign In  
- Create Account  

Complete the registration process.

---

### Step 2 — Generate Your API Key

After logging in, open:
https://developer.riotgames.com/apis

You will find your key under:

```text
Development API Key
```

Click:

```text
Generate New Key
```

Important notes:
- Riot API keys expire every 24 hours  
- You must regenerate a new key daily while testing  
- Without a valid key, SPARK cannot fetch Riot data  

---

### Step 3 — Add Your Key to the Project

Open:

```text
lib/data/riot_link_service.dart
```

Replace:

```dart
static const String apiKey = "PUT_YOUR_RIOT_API_KEY_HERE";
```

Example:

```dart
static const String apiKey = "RGAPI-12345678-abcd-90ef-1234-abcdef987654";
```

---

## 6. OpenRouter API Key for Spark Chatbot

The chatbot feature requires an OpenRouter API Key.

For security reasons, the API key is NOT included in this repository because GitHub blocks exposed secrets.

### Step 1 — Create an OpenRouter Account

Go to:

https://openrouter.ai/activity

Create an account or sign in.

---

### Step 2 — Generate Your API Key

After signing in, generate your own OpenRouter API Key from your account.

---

### Step 3 — Add Your Key to the Project

Open this file:

```text
lib/pages/player/report_chatbot_page.dart
```

Go to this line:

```dart
static const String _openRouterKey = 'YOUR_API_KEY';
```

Replace `YOUR_API_KEY` with your own OpenRouter API key.

Example:

```dart
static const String _openRouterKey = 'sk-or-v1-your-key-here';
```

Important:
Do NOT upload your real API key to GitHub. Replace it with `YOUR_API_KEY` before pushing any changes.

---

## 7. Run the Application

### Web (Edge)

```bash
flutter run -d edge
```

### Web (Chrome)

```bash
flutter run -d chrome
```

### Android / iOS

```bash
flutter run
```

---

## Final Notes

If you need help with:
- API setup  
- README screenshots  
- Troubleshooting  
- Flutter setup  

Feel free to reach out.
