from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.core.config import settings
from app.api.v1 import health, auth, signers, signs, sessions, datasets, recordings, activity
from app.api.v1.recordings import UPLOAD_DIR

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="SignBridge Data Collection Tool API"
)


# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.BACKEND_CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(health.router, prefix=settings.API_V1_PREFIX, tags=["health"])
app.include_router(auth.router, prefix=settings.API_V1_PREFIX + "/auth", tags=["auth"])
app.include_router(signers.router, prefix=settings.API_V1_PREFIX + "/signers", tags=["signers"])
app.include_router(signs.router, prefix=settings.API_V1_PREFIX + "/signs", tags=["signs"])
app.include_router(sessions.router, prefix=settings.API_V1_PREFIX + "/sessions", tags=["sessions"])
app.include_router(recordings.router, prefix=settings.API_V1_PREFIX + "/recordings", tags=["recordings"])
app.include_router(datasets.router, prefix=settings.API_V1_PREFIX + "/datasets", tags=["datasets"])
app.include_router(activity.router, prefix=settings.API_V1_PREFIX + "/activity", tags=["activity"])

# Serve static files (uploads)
app.mount("/uploads", StaticFiles(directory=str(UPLOAD_DIR)), name="uploads")


@app.get("/")
def root():
    return {
        "message": "SignBridge Data Collection Tool API",
        "version": settings.VERSION,
        "status": "running"
    }
