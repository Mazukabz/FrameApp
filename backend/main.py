"""
Frame API - Минималистичный и надежный бэкенд для AI Cinema Platform
Архитектура "Калашников": простой, надежный, эффективный
"""

from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime, timedelta, timezone
import asyncpg
import os
from dotenv import load_dotenv
import jwt
import bcrypt

# Загружаем переменные окружения
load_dotenv()

# Конфигурация приложения
app = FastAPI(
    title="Frame API",
    description="AI Cinema Platform Backend",
    version="1.0.0"
)

# CORS настройки для работы с Flutter Web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # В продакшене укажите конкретные домены
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Настройки из окружения
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://user:password@localhost/frame_db")
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Security
security = HTTPBearer()

# ==================== МОДЕЛИ ДАННЫХ ====================
# Pydantic модели для валидации входящих/исходящих данных

class MovieBase(BaseModel):
    """Базовая модель фильма"""
    title: str = Field(..., min_length=1, max_length=200)
    genre: str = Field(..., min_length=1, max_length=50)
    duration: int = Field(..., gt=0, description="Длительность в минутах")
    rating: float = Field(..., ge=0, le=5)
    description: str = Field(..., max_length=1000)
    poster_url: str
    is_new: bool = False

class MovieCreate(MovieBase):
    """Модель для создания фильма"""
    pass

class Movie(MovieBase):
    """Полная модель фильма с ID"""
    id: int
    created_at: datetime
    views_count: int = 0
    
    class Config:
        orm_mode = True

class UserBase(BaseModel):
    """Базовая модель пользователя"""
    email: str = Field(..., pattern=r'^[\w\.-]+@[\w\.-]+\.\w+$')
    username: str = Field(..., min_length=3, max_length=50)

class UserCreate(UserBase):
    """Модель для регистрации"""
    password: str = Field(..., min_length=6)

class User(UserBase):
    """Полная модель пользователя"""
    id: int
    created_at: datetime
    is_active: bool = True
    
    class Config:
        orm_mode = True

class Token(BaseModel):
    """Модель токена авторизации"""
    access_token: str
    token_type: str = "bearer"

class LoginRequest(BaseModel):
    """Модель запроса авторизации"""
    email: str
    password: str

# ==================== БАЗА ДАННЫХ ====================
# Пул соединений для эффективной работы с PostgreSQL

class Database:
    """Менеджер подключения к БД"""
    pool: Optional[asyncpg.Pool] = None
    
    @classmethod
    async def connect(cls):
        """Создание пула соединений при запуске"""
        if not cls.pool:
            cls.pool = await asyncpg.create_pool(
                DATABASE_URL,
                min_size=10,  # Минимум соединений
                max_size=20,  # Максимум соединений
                command_timeout=60
            )
    
    @classmethod
    async def disconnect(cls):
        """Закрытие пула при остановке"""
        if cls.pool:
            await cls.pool.close()
            cls.pool = None
    
    @classmethod
    async def execute(cls, query: str, *args):
        """Выполнение запроса без возврата данных"""
        async with cls.pool.acquire() as conn:
            return await conn.execute(query, *args)
    
    @classmethod
    async def fetch(cls, query: str, *args):
        """Выполнение запроса с возвратом множества записей"""
        async with cls.pool.acquire() as conn:
            return await conn.fetch(query, *args)
    
    @classmethod
    async def fetchrow(cls, query: str, *args):
        """Выполнение запроса с возвратом одной записи"""
        async with cls.pool.acquire() as conn:
            return await conn.fetchrow(query, *args)

# События жизненного цикла приложения
@app.on_event("startup")
async def startup():
    """Инициализация при запуске"""
    await Database.connect()
    print("✅ Database connected")

@app.on_event("shutdown")
async def shutdown():
    """Очистка при остановке"""
    await Database.disconnect()
    print("❌ Database disconnected")

# ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================

def hash_password(password: str) -> str:
    """Хеширование пароля с помощью bcrypt"""
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Проверка пароля"""
    return bcrypt.checkpw(
        plain_password.encode('utf-8'), 
        hashed_password.encode('utf-8')
    )

def create_access_token(data: dict) -> str:
    """Создание JWT токена"""
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Получение текущего пользователя из токена"""
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: int = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials"
            )
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials"
        )
    
    # Получаем пользователя из БД
    user = await Database.fetchrow(
        "SELECT * FROM users WHERE id = $1 AND is_active = true",
        user_id
    )
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    return dict(user)

# ==================== API ENDPOINTS ====================

@app.get("/", tags=["General"])
async def root():
    """Корневой эндпоинт для проверки работоспособности"""
    return {
        "message": "Frame API is running",
        "version": "1.0.0",
        "docs": "/docs"
    }

# --- Аутентификация ---

@app.post("/api/auth/register", response_model=Token, tags=["Auth"])
async def register(user: UserCreate):
    """
    Регистрация нового пользователя
    - Проверяет уникальность email
    - Хеширует пароль
    - Создает JWT токен
    """
    # Проверяем, существует ли пользователь
    existing = await Database.fetchrow(
        "SELECT id FROM users WHERE email = $1",
        user.email
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Создаем пользователя
    hashed_password = hash_password(user.password)
    new_user = await Database.fetchrow(
        """
        INSERT INTO users (email, username, password_hash, created_at)
        VALUES ($1, $2, $3, $4)
        RETURNING id
        """,
        user.email, user.username, hashed_password, datetime.utcnow()
    )
    
    # Создаем токен
    access_token = create_access_token(data={"sub": new_user["id"]})
    return Token(access_token=access_token)

@app.post("/api/auth/login", response_model=Token, tags=["Auth"])
async def login(request: LoginRequest):
    """
    Авторизация пользователя
    - Проверяет email и пароль
    - Возвращает JWT токен
    """
    # Находим пользователя
    user = await Database.fetchrow(
        "SELECT id, password_hash FROM users WHERE email = $1 AND is_active = true",
        request.email
    )
    
    if not user or not verify_password(request.password, user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    # Создаем токен
    access_token = create_access_token(data={"sub": user["id"]})
    return Token(access_token=access_token)

# --- Фильмы ---

@app.get("/api/movies", response_model=List[Movie], tags=["Movies"])
async def get_movies(
    skip: int = 0,
    limit: int = 100,
    genre: Optional[str] = None
):
    """
    Получение списка фильмов
    - Поддерживает пагинацию
    - Фильтрация по жанру
    """
    query = """
        SELECT * FROM movies 
        WHERE ($1::text IS NULL OR genre = $1)
        ORDER BY created_at DESC
        LIMIT $2 OFFSET $3
    """
    
    rows = await Database.fetch(query, genre, limit, skip)
    return [dict(row) for row in rows]

@app.get("/api/movies/{movie_id}", response_model=Movie, tags=["Movies"])
async def get_movie(movie_id: int):
    """Получение информации о конкретном фильме"""
    movie = await Database.fetchrow(
        "SELECT * FROM movies WHERE id = $1",
        movie_id
    )
    
    if not movie:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Movie not found"
        )
    
    # Увеличиваем счетчик просмотров
    await Database.execute(
        "UPDATE movies SET views_count = views_count + 1 WHERE id = $1",
        movie_id
    )
    
    return dict(movie)

@app.post("/api/movies", response_model=Movie, tags=["Movies"])
async def create_movie(
    movie: MovieCreate,
    current_user: dict = Depends(get_current_user)
):
    """
    Создание нового фильма (требует авторизации)
    - Только для авторизованных пользователей
    - Автоматически связывается с создателем
    """
    new_movie = await Database.fetchrow(
            """
            INSERT INTO movies
            (title, genre, duration, rating, description, poster_url, is_new, created_at, user_id)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING *
            """,
            movie.title, movie.genre, movie.duration, movie.rating,
            movie.description, movie.poster_url, movie.is_new, datetime.now(timezone.utc), current_user['id'] # <-- Обратите внимание на current_user['id']
        )