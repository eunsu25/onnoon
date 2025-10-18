from fastapi import FastAPI, HTTPException, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app.database import SessionLocal, engine
from app.models import Base, User, EyeFatigueRecord
from typing import List
from fastapi.middleware.cors import CORSMiddleware

# FastAPI 인스턴스 생성
app = FastAPI()

# ✅ 여기에 CORS 설정 추가
origins = [
    "http://localhost:3000",       # 프론트엔드가 로컬에서 띄울 경우
    "http://127.0.0.1:3000",       # 같은 의미
    "http://your-teammate-ip:3000" # 조원이 다른 PC에서 접근할 경우
]

# 데이터베이스 테이블 생성
Base.metadata.create_all(bind=engine)

@app.get("/")
def read_root():
    return {"message": "Welcome to the API"}

# Pydantic 모델 정의
class EyeData(BaseModel):
    blink_speed: float
    iris_dilation: float
    eye_movement_pattern: str

class UserCreate(BaseModel):
    name: str
    email: str

# DB 세션 생성 함수
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# 사용자 생성 API(회원가입)
@app.post("/users/")
def create_User(user: UserCreate, db: Session = Depends(get_db)):
    db_user = User(name=user.name, email=user.email)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

# 피로도 계산 및 DB 저장 API
@app.post("/api/eye-fatigue")
def calculate_eye_fatigue(data: EyeData, db: Session = Depends(get_db)):
    # 피로도 계산
    fatigue_score = data.blink_speed * 0.5 + data.iris_dilation * 0.3
    
    # 피로도 기록 DB에 저장
    db_record = EyeFatigueRecord(user_id=1, fatigue_score=fatigue_score)  # 예시로 user_id=1
    db.add(db_record)
    db.commit()
    db.refresh(db_record)

    # 사용자 전체 조회 API
@app.get("/users/", response_model=List[UserCreate])
def get_users(db: Session = Depends(get_db)):
    return db.query(User).all()

# 사용자 1명 조회 API
@app.get("/users/{user_id}")
def get_user(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

# 특정 사용자의 피로도 기록 전체 조회 API
@app.get("/users/{user_id}/records")
def get_eye_fatigue_records(user_id: int, db: Session = Depends(get_db)):
    records = db.query(EyeFatigueRecord).filter(EyeFatigueRecord.user_id == user_id).all()
    return records

# 가장 최근 피로도 기록 조회 API
@app.get("/users/{user_id}/records/latest")
def get_latest_record(user_id: int, db: Session = Depends(get_db)):
    record = db.query(EyeFatigueRecord).filter(EyeFatigueRecord.user_id == user_id).order_by(EyeFatigueRecord.created_at.desc()).first()
    if not record:
        raise HTTPException(status_code=404, detail="No record found")
    return record
    
    return {"fatigue_score": fatigue_score}

from fastapi import FastAPI, HTTPException, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app.database import SessionLocal, engine
from app.models import Base, User, EyeFatigueRecord
from typing import List
from fastapi.middleware.cors import CORSMiddleware

# FastAPI 인스턴스 생성
app = FastAPI()

# ✅ 여기에 CORS 설정 추가
origins = [
    "http://localhost:3000",       # 프론트엔드가 로컬에서 띄울 경우
    "http://127.0.0.1:3000",       # 같은 의미
    "http://your-teammate-ip:3000" # 조원이 다른 PC에서 접근할 경우
]

# 데이터베이스 테이블 생성
Base.metadata.create_all(bind=engine)

@app.get("/")
def read_root():
    return {"message": "Welcome to the API"}

# Pydantic 모델 정의
class EyeData(BaseModel):
    blink_speed: float
    iris_dilation: float
    eye_movement_pattern: str

class UserCreate(BaseModel):
    name: str
    email: str

# DB 세션 생성 함수
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# 사용자 생성 API(회원가입)
@app.post("/users/")
def create_User(user: UserCreate, db: Session = Depends(get_db)):
    db_user = User(name=user.name, email=user.email)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

# 피로도 계산 및 DB 저장 API
@app.post("/api/eye-fatigue")
def calculate_eye_fatigue(data: EyeData, db: Session = Depends(get_db)):
    # 피로도 계산
    fatigue_score = data.blink_speed * 0.5 + data.iris_dilation * 0.3
    
    # 피로도 기록 DB에 저장
    db_record = EyeFatigueRecord(user_id=1, fatigue_score=fatigue_score)  # 예시로 user_id=1
    db.add(db_record)
    db.commit()
    db.refresh(db_record)

    # 사용자 전체 조회 API
@app.get("/users/", response_model=List[UserCreate])
def get_users(db: Session = Depends(get_db)):
    return db.query(User).all()

# 사용자 1명 조회 API
@app.get("/users/{user_id}")
def get_user(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

# 특정 사용자의 피로도 기록 전체 조회 API
@app.get("/users/{user_id}/records")
def get_eye_fatigue_records(user_id: int, db: Session = Depends(get_db)):
    records = db.query(EyeFatigueRecord).filter(EyeFatigueRecord.user_id == user_id).all()
    return records

# 가장 최근 피로도 기록 조회 API
@app.get("/users/{user_id}/records/latest")
def get_latest_record(user_id: int, db: Session = Depends(get_db)):
    record = db.query(EyeFatigueRecord).filter(EyeFatigueRecord.user_id == user_id).order_by(EyeFatigueRecord.created_at.desc()).first()
    if not record:
        raise HTTPException(status_code=404, detail="No record found")
    return record
    
    return {"fatigue_score": fatigue_score}
