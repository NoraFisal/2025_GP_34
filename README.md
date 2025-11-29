
<p align="left">
  <img src="./SPARK_Logo.png" alt="SPARK Logo" width="200"/>
</p>

# SPARK
**Saudi Platform for AI-Driven Recognition & Knowledge**

---

## Introduction
The esports industry in Saudi Arabia is growing rapidly, supported by Vision 2030 initiatives and the increasing interest of millions of players.  
Despite this progress, many talented players still face challenges in gaining fair visibility and accessing professional opportunities.  
SPARK aims to address this gap by providing a localized mobile platform that allows Saudi players to showcase their skills, build teams, and connect with tournaments in an organized and trustworthy way.

---

## Key Features
- Player profiles linked with in-game data (via Riot Games API).  
- Team creation and role-based matchmaking.  
- AI-powered analysis to suggest performance improvements and estimate win probabilities.  
- Messaging system for players and teams.  
- Tournament and event management hub with filters for accessibility.  

---

## Technology
- **Framework:** Flutter (for mobile app)  
- **Backend:** Python (Flask)  
- **Database:** MySQL / Firebase  
- **AI Tools:** Scikit-learn, Pandas  
- **API:** Riot Games API  
- **Version Control:** GitHub  

---

# 🚀 SPARK – Launching Instructions

Follow these steps to set up and run the project correctly on your machine.

---

## 1. Clone the Repository
git clone https://github.com/NoraFisal/2025_GP_34.git

## 2. Navigate to the Project Folder
cd 2025_GP_34

## 3. Install Flutter Dependencies
flutter pub get

---

## 4. Download Required ML Model Files (IMPORTANT)

GitHub does NOT include the machine-learning model files because they exceed GitHub’s size limit.

You must download them manually from Google Drive:

Model Files:
https://drive.google.com/drive/folders/1gF6DuxyyolP9jRGfX8MOLemnDZUzYaHs?usp=sharing

After downloading, place the files inside:

assets/model/

Required files:
- random_forest_v5.json
- feature_means_v5.json
- feature_cols_v5.txt

Then run:
flutter pub get

---

## 5. Riot API Key (REQUIRED)

To run SPARK, you MUST generate your own Riot API Key.

### Step 1 — Create a Riot Developer Account
Go to:
https://developer.riotgames.com/

Click:
“Sign In” → “Create Account”

Complete the registration.

### Step 2 — Generate Your API Key
After logging in, go to your dashboard:
https://developer.riotgames.com/apis

You will find your API Key under:
**"Development API Key"**

Click:
**"Generate New Key"**

Important Notes:
- Riot API keys expire every **24 hours**.
- You must regenerate a new key daily if you're testing the application.
- Without a valid key, the application will NOT fetch Riot data.

### Step 3 — Add Your Key to the Project
Open the file:

lib/data/riot_link_service.dart

Update this line:
static const String apiKey = "PUT_YOUR_RIOT_API_KEY_HERE";

Example:
static const String apiKey = "RGAPI-12345678-abcd-90ef-1234-abcdef987654";

(Replace only the key, keep the quotation marks.)

---

## 6. Run the Application

Web (Edge):
flutter run -d edge

Web (Chrome):
flutter run -d chrome

Mobile (Android/iOS):
flutter run

---

## ✔️ You're all set!
If you need help with API setup, screenshots for the README, or troubleshooting — just tell me.

---

## ✔️ You're all set!
If you need help with environment setup, screenshots for the README, or troubleshooting — just tell me.

