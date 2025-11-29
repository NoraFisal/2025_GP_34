
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

Follow these steps to run the project correctly on your machine.

---

## 1️⃣ Clone the Repository
git clone https://github.com/NoraFisal/2025_GP_34.git

---

## 2️⃣ Navigate to the Project Folder
cd 2025_GP_34

---

## 3️⃣ Install Flutter Dependencies
flutter pub get

---

## 4️⃣ Download Required ML Model Files (IMPORTANT)

GitHub does NOT include the machine-learning model files because they exceed GitHub’s size limit.

You must download them manually from Google Drive:

🔗 Model Files:  
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

## 5️⃣ Run the Application

### Web (Microsoft Edge)
flutter run -d edge

### Web (Chrome)
flutter run -d chrome

### Mobile (Android/iOS)
flutter run

---

## ✔️ You're all set!
If you need help with environment setup, screenshots for the README, or troubleshooting — just tell me.

