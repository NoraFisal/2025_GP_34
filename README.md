
<p align="center">
  <img src="https://github.com/NoraFisal/2025_GP_34/blob/main/SPARK_Logo.png" width="180">
</p>

<h1 align="center">SPARK – Esports AI Platform</h1>

---

## 📌 Overview
SPARK is an AI-powered esports platform designed to help Saudi players, teams, and organizers connect, form professional teams, and analyze team performance using machine-learning insights.

The platform predicts team win probability, generates the top 3 optimal lineups, and provides a clean, user-friendly mobile app experience built with Flutter and Firebase.

This repository contains:
- Mobile app source code  
- AI model integration files  
- Project documentation  
- Sprint-1 deliverables

---

## 🎯 Project Goal
To provide an intelligent esports environment that:
- Helps players showcase skills professionally  
- Helps teams form optimal lineups  
- Supports organizers in tournaments  
- Predicts team win probability using AI  
- Enhances Saudi esports ecosystem aligned with Vision 2030  

---

## 🛠️ Technologies Used
### **Frontend**
- Flutter (Dart)

### **Backend**
- Firebase Authentication  
- Firebase Firestore  
- Firebase Storage  

### **AI & Data**
- Python  
- Pandas, NumPy  
- Scikit-Learn (Random Forest Model)  
- Riot Games API  
- Kaggle datasets  

### **Design & Management**
- Figma  
- Jira  
- GitHub  

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

>>>>>>> 87849e966cb28734c2b450c6b4883146d5009c1b
