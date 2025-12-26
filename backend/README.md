# 🐍 Smart Task Backend

The backend service for the Smart Task Automation application. Built with Python, this service handles data processing, validation logic, and API endpoints.

---

## 📂 Project Structure

* **`main.py`**: Application entry point and server configuration.
* **`logic.py`**: Core business logic and data processing algorithms.
* **`schemas.py`**: Data models and input validation using Pydantic/dataclasses.
* **`test_logic.py`**: Unit tests ensuring logic stability.

---

## ⚙️ Setup & Installation

### 1. Prerequisites
* Python 3.10 or higher
* pip (Python Package Manager)

---

### 2. Virtual Environment
It is best practice to run this project in an isolated environment.

**Windows:**
```Bash
python -m venv venv
.\venv\Scripts\activate
```

**macOS / Linux:**
```Bash
python3 -m venv venv
source venv/bin/activate
```

---

### 3. Install Dependencies
```Bash
pip install -r requirements.txt
```

---

### 4. Configuration
Create a .env file in this directory to store secrets (ignored by Git for security).
```Bash
`#` Example .env configuration
DATABASE_URL=sqlite:///./sql_app.db
SECRET_KEY=your_secret_key_here
```

---

## 🚀 Usage
`#` Running the Application
To start the backend server:
```Bash
python main.py
```

---

# Running Tests
To execute the test suite (via pytest):
```Bash
pytest
```

---

## 👤 Author

[Niranjan Karupothula] (https://github.com/karupothula/) – niranjankarupothula@gmail.com | [LinkedIn](https://www.linkedin.com/in/karupothula/)