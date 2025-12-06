from fastapi import FastAPI, Request, HTTPException, Depends
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import httpx
import os
import asyncio
from typing import Optional
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Expense Pilot API Gateway",
    description="API Gateway for Expense Pilot microservices",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    redirect_slashes=False  # Disable automatic slash redirection
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify allowed origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Service URLs from environment variables
AUTH_SERVICE_URL = os.getenv("AUTH_SERVICE_URL")
EXPENSES_SERVICE_URL = os.getenv("EXPENSES_SERVICE_URL")
AUDIT_SERVICE_URL = os.getenv("AUDIT_SERVICE_URL")
NOTIFICATION_SERVICE_URL = os.getenv("NOTIFICATION_SERVICE_URL")
API_SECRET_KEY = os.getenv("API_SECRET_KEY")

# HTTP client with timeout
timeout = httpx.Timeout(30.0, connect=10.0)
client = httpx.AsyncClient(timeout=timeout)

async def forward_request(
    request: Request,
    target_url: str,
    path: str = None
) -> JSONResponse:
    """Forward request to target microservice"""
    try:
        # Use provided path or extract from request
        if path is None:
            path = request.url.path
        
        # Build target URL
        full_url = f"{target_url}{path}"
        
        # Extract query parameters
        query_params = str(request.url.query)
        if query_params:
            full_url += f"?{query_params}"
        
        # Get request body if present
        body = None
        if request.method in ["POST", "PUT", "PATCH"]:
            body = await request.body()
        
        # Forward headers (exclude host and content-length)
        headers = dict(request.headers)
        headers.pop("host", None)
        headers.pop("content-length", None)
        
        # Remove any existing X-API-Key header to avoid duplication
        headers.pop("x-api-key", None)
        headers.pop("X-API-Key", None)
        
        # Always add the internal API authentication header
        headers["X-API-Key"] = API_SECRET_KEY if API_SECRET_KEY else ""
        
        logger.info(f"Forwarding {request.method} {full_url}")
        
        # Make request to microservice
        response = await client.request(
            method=request.method,
            url=full_url,
            content=body,
            headers=headers
        )
        
        # Return response
        return JSONResponse(
            content=response.json() if response.headers.get("content-type", "").startswith("application/json") else response.text,
            status_code=response.status_code,
            headers=dict(response.headers)
        )
        
    except httpx.TimeoutException:
        logger.error(f"Timeout forwarding request to {target_url}")
        raise HTTPException(status_code=504, detail="Gateway timeout")
    except httpx.RequestError as e:
        logger.error(f"Request error forwarding to {target_url}: {e}")
        raise HTTPException(status_code=502, detail="Bad gateway")
    except Exception as e:
        logger.error(f"Unexpected error forwarding to {target_url}: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

# Health check endpoint
@app.get("/health")
async def health_check():
    """Gateway health check"""
    return {"status": "healthy", "service": "api-gateway"}

# Service health checks
@app.get("/health/services")
async def service_health_checks():
    """Check health of all microservices"""
    services = {
        "auth-service": f"{AUTH_SERVICE_URL}/health",
        "expenses-service": f"{EXPENSES_SERVICE_URL}/health",
        "audit-service": f"{AUDIT_SERVICE_URL}/health",
    }
    
    results = {}
    
    async def check_service(name: str, url: str):
        try:
            response = await client.get(url, timeout=5.0)
            results[name] = {
                "status": "healthy" if response.status_code == 200 else "unhealthy",
                "response_time": response.elapsed.total_seconds(),
                "status_code": response.status_code
            }
        except Exception as e:
            results[name] = {
                "status": "unhealthy",
                "error": str(e)
            }
    
    # Check all services concurrently
    await asyncio.gather(*[check_service(name, url) for name, url in services.items()])
    
    return {"services": results}

# Auth service routes
@app.api_route("/auth/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def auth_proxy(request: Request, path: str):
    """Forward auth requests to auth service"""
    return await forward_request(request, AUTH_SERVICE_URL, f"/auth/{path}")

# Users routes - handle both with and without trailing slash in the path normalization
@app.api_route("/users/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def users_with_path_proxy(request: Request, path: str):
    """Forward user requests with path to auth service"""
    return await forward_request(request, AUTH_SERVICE_URL, f"/users/{path}")

@app.post("/users")
@app.get("/users") 
@app.put("/users")
@app.delete("/users")
@app.patch("/users")
async def users_base_proxy(request: Request):
    """Forward base user requests to auth service"""
    return await forward_request(request, AUTH_SERVICE_URL, "/users")

# Expenses service routes
@app.api_route("/api/companies/{company_id}/expenses/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def expenses_proxy(request: Request, company_id: int, path: str = ""):
    """Forward expense requests to expenses service"""
    expense_path = f"/api/companies/{company_id}/expenses"
    if path:
        expense_path += f"/{path}"
    return await forward_request(request, EXPENSES_SERVICE_URL, expense_path)

@app.api_route("/api/companies/{company_id}/expenses", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def expenses_base_proxy(request: Request, company_id: int):
    """Forward base expense requests to expenses service"""
    return await forward_request(request, EXPENSES_SERVICE_URL, f"/api/companies/{company_id}/expenses")

# Audit service routes
@app.api_route("/api/v1/audit_logs/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def audit_logs_proxy(request: Request, path: str = ""):
    """Forward audit_logs requests to audit service"""
    audit_path = "/api/v1/audit_logs"
    if path:
        audit_path += f"/{path}"
    return await forward_request(request, AUDIT_SERVICE_URL, audit_path)

@app.api_route("/api/v1/audit_logs", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def audit_logs_base_proxy(request: Request):
    """Forward base audit_logs requests to audit service"""
    return await forward_request(request, AUDIT_SERVICE_URL, "/api/v1/audit_logs")

# Notification service routes
@app.api_route("/notifications/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def notifications_proxy(request: Request, path: str):
    """Forward notification requests to notification service"""
    return await forward_request(request, NOTIFICATION_SERVICE_URL, f"/notifications/{path}")

# Swagger documentation proxying
@app.get("/swagger/auth")
async def auth_swagger_proxy(request: Request):
    """Proxy auth service swagger docs"""
    return await forward_request(request, AUTH_SERVICE_URL, "/api-docs")

@app.get("/swagger/expenses")
async def expenses_swagger_proxy(request: Request):
    """Proxy expenses service swagger docs"""
    return await forward_request(request, EXPENSES_SERVICE_URL, "/swagger/index.html")

# Startup event
@app.on_event("startup")
async def startup_event():
    logger.info("🚀 API Gateway starting up...")
    logger.info(f"Auth Service: {AUTH_SERVICE_URL}")
    logger.info(f"Expenses Service: {EXPENSES_SERVICE_URL}")
    logger.info(f"Audit Service: {AUDIT_SERVICE_URL}")
    logger.info(f"Notification Service: {NOTIFICATION_SERVICE_URL}")

# Shutdown event
@app.on_event("shutdown")
async def shutdown_event():
    await client.aclose()
    logger.info("API Gateway shutting down...")

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port) 