from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel
from typing import List, Optional
from sqlalchemy import create_engine, Column, Integer, String, Enum, Text, Date, DateTime, ForeignKey
from sqlalchemy.orm import declarative_base
from sqlalchemy.orm import sessionmaker, relationship, Session
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi.responses import RedirectResponse
import enum
import datetime

# --- CONFIG ---
DATABASE_URL = "mysql+mysqlconnector://root:Bones&30@localhost:3307/iseras_db"
SECRET_KEY = "your-secret-key"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# --- SQLAlchemy Setup ---
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
Base = declarative_base()

# --- Security ---
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/token")
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# --- Enums ---
class UserType(str, enum.Enum):
    Patient = "Patient"
    Therapist = "Therapist"

class MoodType(str, enum.Enum):
    Happy = "Happy"
    Sad = "Sad"
    Anxious = "Anxious"
    Calm = "Calm"
    Angry = "Angry"
    Neutral = "Neutral"

# --- Models ---
class User(Base):
    __tablename__ = "Users"
    user_id = Column(Integer, primary_key=True, index=True)
    full_name = Column(String(100), nullable=False)
    email = Column(String(100), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    user_type = Column(Enum(UserType), nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

class HealthLog(Base):
    __tablename__ = "HealthLogs"
    log_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("Users.user_id"), nullable=False)
    entry_date = Column(Date, nullable=False)
    mood = Column(Enum(MoodType), nullable=False)
    journal = Column(Text)

    user = relationship("User")

# --- Pydantic Schemas ---
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None

class UserCreate(BaseModel):
    full_name: str
    email: str
    password_hash: str  # Plain password, to be hashed before storing
    user_type: UserType

class UserRead(UserCreate):
    user_id: int

    model_config = {
        "from_attributes": True
    }

class HealthLogCreate(BaseModel):
    user_id: int
    entry_date: datetime.date
    mood: MoodType
    journal: str

class HealthLogRead(HealthLogCreate):
    log_id: int

    model_config = {
        "from_attributes": True
    }


# --- FastAPI App ---
app = FastAPI(
    title="Iseras API",
    description="Mental health app API",
    version="1.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# app = FastAPI(title="Iseras Mental Health API", version="1.0.0")

# --- Auth Helpers ---
def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[datetime.timedelta] = None):
    to_encode = data.copy()
    expire = datetime.datetime.utcnow() + (expires_delta or datetime.timedelta(minutes=15))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def get_user_by_email(db: Session, email: str):
    return db.query(User).filter(User.email == email).first()

def authenticate_user(db: Session, email: str, password: str):
    user = get_user_by_email(db, email)
    if not user or not verify_password(password, user.password_hash):
        return False
    return user

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(lambda: SessionLocal())):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        return get_user_by_email(db, email)
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

# --- Dependency ---
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- Token Route ---
@app.get("/")
def redirect_to_docs():
    return RedirectResponse(url="/docs")

@app.post("/token", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(status_code=400, detail="Incorrect email or password")
    access_token = create_access_token(data={"sub": user.email})
    return {"access_token": access_token, "token_type": "bearer"}

# --- CRUD Routes ---
@app.post("/users/", response_model=UserRead)
def create_user(user: UserCreate, db: Session = Depends(get_db)):
    user.password_hash = get_password_hash(user.password_hash)
    db_user = User(**user.dict())
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

@app.get("/users/", response_model=List[UserRead])
def list_users(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return db.query(User).all()

@app.get("/users/{user_id}", response_model=UserRead)
def get_user(user_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    user = db.query(User).filter(User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@app.put("/users/{user_id}", response_model=UserRead)
def update_user(user_id: int, user: UserCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    db_user = db.query(User).filter(User.user_id == user_id).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    for key, value in user.dict().items():
        setattr(db_user, key, get_password_hash(value) if key == 'password_hash' else value)
    db.commit()
    db.refresh(db_user)
    return db_user

@app.delete("/users/{user_id}")
def delete_user(user_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    user = db.query(User).filter(User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    db.delete(user)
    db.commit()
    return {"message": "User deleted"}

@app.post("/logs/", response_model=HealthLogRead)
def create_log(log: HealthLogCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    db_log = HealthLog(**log.dict())
    db.add(db_log)
    db.commit()
    db.refresh(db_log)
    return db_log

@app.get("/logs/", response_model=List[HealthLogRead])
def list_logs(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return db.query(HealthLog).all()

@app.get("/logs/{log_id}", response_model=HealthLogRead)
def get_log(log_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    log = db.query(HealthLog).filter(HealthLog.log_id == log_id).first()
    if not log:
        raise HTTPException(status_code=404, detail="Log not found")
    return log

@app.put("/logs/{log_id}", response_model=HealthLogRead)
def update_log(log_id: int, log: HealthLogCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    db_log = db.query(HealthLog).filter(HealthLog.log_id == log_id).first()
    if not db_log:
        raise HTTPException(status_code=404, detail="Log not found")
    for key, value in log.dict().items():
        setattr(db_log, key, value)
    db.commit()
    db.refresh(db_log)
    return db_log

@app.delete("/logs/{log_id}")
def delete_log(log_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    log = db.query(HealthLog).filter(HealthLog.log_id == log_id).first()
    if not log:
        raise HTTPException(status_code=404, detail="Log not found")
    db.delete(log)
    db.commit()
    return {"message": "Log deleted"}

if __name__ == "__main__":
    import uvicorn
    Base.metadata.create_all(bind=engine)
    uvicorn.run(app, host="127.0.0.1", port=8000)