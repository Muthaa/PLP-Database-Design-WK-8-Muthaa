# PLP-Database-Design-WK-8-Muthaa

A secure and scalable mental health tracking API built with **FastAPI** and **MySQL**. This API supports authentication, user management, and mood/health logging for mental wellness applications.

---

## 🚀 Features

- JWT Authentication (OAuth2 Password Flow)
- CRUD operations for:
  - Users (Patients & Therapists)
  - Health Logs (Mood Tracking)
- SQLAlchemy ORM integration
- Swagger UI and ReDoc API docs
- Secure password hashing with Bcrypt

---

## 🧰 Tech Stack

- Python 3.10+
- FastAPI
- MySQL 8+
- SQLAlchemy
- Passlib (bcrypt)
- python-jose (JWT handling)

---

## 🔧 Installation Guide

### 1. Clone the Repository
```bash
git clone https://github.com/your-username/iseras-api.git
cd iseras-api
```

### 2. Install Dependencies
```bash
pip install fastapi[all] sqlalchemy mysql-connector-python passlib[bcrypt] python-jose
```

### 3. Set Up MySQL Database
```sql
-- Inside MySQL CLI or Workbench
CREATE DATABASE iseras_app;
```

Update `DATABASE_URL` in `main.py`:
```python
DATABASE_URL = "mysql+mysqlconnector://<user>:<password>@localhost:3306/iseras_app"
```

### 4. Create Tables
Open `main.py` and add the following lines at the bottom of the file, right after your route definitions:
```python
if __name__ == "__main__":
    import uvicorn
    Base.metadata.create_all(bind=engine)
    uvicorn.run(app, host="127.0.0.1", port=8000)
```
This will create all necessary tables on the database.

Run the file once:
```bash
python main.py
```
Then remove or comment that line.

### 5. Run the API Server
```bash
uvicorn main:app --reload
```

### 6. Explore API Docs
- Swagger: [http://localhost:8000/docs](http://localhost:8000/docs)
- ReDoc: [http://localhost:8000/redoc](http://localhost:8000/redoc)

---

## 🔑 Authentication (JWT)

### Obtain Access Token:
```bash
curl -X POST http://localhost:8000/token \
    -d 'username=your_email@example.com' \
    -d 'password=your_password'
```

### Use Token:
Add `Authorization: Bearer <your_token>` header to all protected requests.

---

## 🔄 Sample API Usage

### Register a User
```bash
POST /users/
{
  "full_name": "Jane Doe",
  "email": "jane@example.com",
  "password_hash": "plainpassword",
  "user_type": "Patient"
}
```

### Add a Health Log
```bash
POST /logs/
{
  "user_id": 1,
  "entry_date": "2025-05-01",
  "mood": "Calm",
  "journal": "Feeling grounded today."
}
```

---

## ✅ Endpoints Overview

| Method | Endpoint         | Description               |
|--------|------------------|---------------------------|
| POST   | /token           | Get JWT token             |
| POST   | /users/          | Register a user           |
| GET    | /users/          | List all users            |
| GET    | /users/{id}      | Get single user           |
| PUT    | /users/{id}      | Update user               |
| DELETE | /users/{id}      | Delete user               |
| POST   | /logs/           | Create a health log       |
| GET    | /logs/           | List all logs             |
| GET    | /logs/{id}       | Retrieve log              |
| PUT    | /logs/{id}       | Update log                |
| DELETE | /logs/{id}       | Delete log                |

---
