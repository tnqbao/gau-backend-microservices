# Gau Backend Microservices System Architecture

## System Overview Diagram

```mermaid
graph TB
    subgraph External["External Layer"]
        Client[Client Applications<br/>Web/Mobile/Desktop]
    end

    subgraph K8s["Kubernetes Cluster"]
        subgraph Ingress["Ingress Layer"]
            Traefik[Traefik<br/>Ingress Controller]
        end

        subgraph Services["Microservices Layer"]
            AccountSvc[Gau Account Service]
            AuthSvc[Gau Authorization Service]
            CDNSvc[Gau CDN Service]
            UploadSvc[Gau Upload Service]
            EmailSvc[Gau Email Service]
        end
    end

    subgraph SharedInfra["Shared Infrastructure"]
        PgPool[(PgPool<br/>PostgreSQL Connection Pooler)]
        CloudflareR2[(Cloudflare R2<br/>Object Storage)]
        Grafana[Grafana OTLP<br/>Observability Platform]
    end

    subgraph DedicatedInfra["Dedicated Infrastructure"]
        subgraph AccountInfra["Account Service Resources"]
            AccountDB[(PostgreSQL<br/>Account Database)]
        end

        subgraph AuthInfra["Authorization Service Resources"]
            AuthDB[(PostgreSQL<br/>Auth Database)]
            AuthRedis[(Redis<br/>Token Store)]
        end

        subgraph CDNInfra["CDN Service Resources"]
            CDNRedis[(Redis<br/>Image Cache)]
        end

        subgraph EmailInfra["Email Service Resources"]
            RabbitMQ[RabbitMQ<br/>Message Queue]
            SMTP[SMTP Server]
        end
    end

    subgraph ExternalAPIs["External APIs"]
        GoogleOAuth[Google OAuth API]
    end

    Client -->|HTTPS| Traefik
    
    Traefik -->|Route: /api/v2/account/*| AccountSvc
    Traefik -->|Route: /images/*| CDNSvc
    
    AccountSvc -->|Internal HTTP| AuthSvc
    AccountSvc -->|Internal HTTP| UploadSvc
    AccountSvc -->|HTTPS| GoogleOAuth
    
    AccountSvc --> PgPool
    PgPool --> AccountDB
    
    AuthSvc --> PgPool
    PgPool --> AuthDB
    AuthSvc --> AuthRedis
    
    CDNSvc --> CloudflareR2
    CDNSvc --> CDNRedis
    
    UploadSvc --> CloudflareR2
    
    RabbitMQ -->|Consume Messages| EmailSvc
    EmailSvc --> SMTP
    
    AccountSvc -.->|Metrics & Logs| Grafana
    AuthSvc -.->|Metrics & Logs| Grafana
    CDNSvc -.->|Metrics & Logs| Grafana
    UploadSvc -.->|Metrics & Logs| Grafana
    EmailSvc -.->|Metrics & Logs| Grafana

    style Traefik fill:#37b24d,stroke:#2b8a3e,color:#fff
    style AccountSvc fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style AuthSvc fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style CDNSvc fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style UploadSvc fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style EmailSvc fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style PgPool fill:#ff6b6b,stroke:#fa5252,color:#fff
    style CloudflareR2 fill:#ff6b6b,stroke:#fa5252,color:#fff
    style Grafana fill:#ff6b6b,stroke:#fa5252,color:#fff
```

The system overview diagram illustrates the microservices architecture deployed on Kubernetes Cluster. Client requests flow through the Traefik Ingress Controller, which routes them to appropriate microservices. The system utilizes a combination of shared infrastructure (PgPool, Cloudflare R2, Grafana) and dedicated resources for each service (PostgreSQL databases, Redis instances, RabbitMQ). All services send metrics and logs to Grafana for monitoring.

---

## Gau Account Service

```mermaid
graph TB
    subgraph External["External Layer"]
        Client[HTTP Client]
        GoogleAPI[Google OAuth API]
    end

    subgraph AccountService["Gau Account Service"]
        Router[HTTP Router<br/>Gin Framework]
        Middleware[Middlewares<br/>CORS, Auth, Logger]
        Controller[Controllers<br/>Login, Register, Profile, MFA]
        Repository[Repository Layer<br/>Database Operations]
        Provider[Provider Layer<br/>External Service Clients]
    end

    subgraph ExternalServices["External Services"]
        AuthService[Gau Authorization Service<br/>Token Management]
        UploadService[Gau Upload Service<br/>File Upload]
    end

    subgraph Infrastructure["Infrastructure"]
        Postgres[(PostgreSQL<br/>via PgPool<br/>Account Database)]
        Logger[Logger Client<br/>Grafana OTLP]
    end

    Client -->|HTTP Request| Router
    Router --> Middleware
    Middleware --> Controller
    Controller --> Repository
    Controller --> Provider
    
    Repository --> Postgres
    
    Provider -->|Create Token<br/>Renew Token<br/>Validate Token<br/>Revoke Token| AuthService
    Provider -->|Upload Avatar| UploadService
    Provider -->|SSO Authentication| GoogleAPI
    
    Controller --> Logger
    Repository --> Logger
    Provider --> Logger

    style Router fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style Controller fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style Repository fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style Provider fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style Postgres fill:#ff6b6b,stroke:#fa5252,color:#fff
    style AuthService fill:#37b24d,stroke:#2b8a3e,color:#fff
    style UploadService fill:#37b24d,stroke:#2b8a3e,color:#fff
```

Gau Account Service manages user accounts, handling registration, login, profile management, and MFA. The service connects to a dedicated PostgreSQL database via PgPool to store user information. It integrates with Gau Authorization Service for token management, Gau Upload Service for avatar uploads, and Google OAuth API for SSO functionality. All operations are logged to Grafana.

---

## Gau Authorization Service

```mermaid
graph TB
    subgraph External["Internal Services"]
        InternalClient[Internal Service Clients<br/>Account, Kanban Services]
    end

    subgraph AuthService["Gau Authorization Service"]
        Router[HTTP Router<br/>Gin Framework]
        Middleware[Middlewares<br/>Private Key Validation, CORS]
        Controller[Controllers<br/>Token Management]
        Repository[Repository Layer<br/>Token & Bitmap Operations]
        Provider[Provider Layer<br/>JWT Utils, Logger]
    end

    subgraph Infrastructure["Infrastructure"]
        Postgres[(PostgreSQL<br/>via PgPool<br/>Refresh Token Store)]
        Redis[(Redis<br/>Token Bitmap Store)]
        Logger[Logger Client<br/>Grafana OTLP]
    end

    InternalClient -->|HTTP Request<br/>Private-Key Header| Router
    Router --> Middleware
    Middleware --> Controller
    Controller --> Repository
    Controller --> Provider
    
    Repository -->|Store Refresh Tokens| Postgres
    Repository -->|Token Bitmap<br/>Active/Revoked Status| Redis
    
    Controller --> Logger
    Repository --> Logger

    style Router fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style Controller fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style Repository fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style Provider fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style Postgres fill:#ff6b6b,stroke:#fa5252,color:#fff
    style Redis fill:#ff6b6b,stroke:#fa5252,color:#fff
```

Gau Authorization Service is responsible for token management and authorization in the system. The service uses Private Key authentication to validate requests from internal services. It connects to a dedicated PostgreSQL database to store refresh tokens and a dedicated Redis instance to manage token bitmaps, enabling fast token revocation. All token operations are logged to Grafana.

---

## Gau CDN Service

```mermaid
graph TB
    subgraph External["External Layer"]
        Client[HTTP Client<br/>Public Access]
    end

    subgraph CDNService["Gau CDN Service"]
        Router[HTTP Router<br/>Gin Framework]
        Controller[Controllers<br/>Image Serving]
        Repository[Repository Layer<br/>Cache Operations]
        Provider[Provider Layer<br/>Logger]
    end

    subgraph Infrastructure["Infrastructure"]
        Redis[(Redis<br/>Image Cache<br/>LRU Strategy)]
        CloudflareR2[(Cloudflare R2<br/>Object Storage)]
        Logger[Logger Client<br/>Grafana OTLP]
    end

    Client -->|GET /images/*| Router
    Router --> Controller
    Controller --> Repository
    Controller --> Provider
    
    Repository -->|Check Cache| Redis
    Redis -->|Cache Miss| Repository
    Repository -->|Fetch Image| CloudflareR2
    CloudflareR2 -->|Image Binary| Repository
    Repository -->|Store Cache<br/>TTL & Size Limit| Redis
    
    Controller --> Logger

    style Router fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style Controller fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style Repository fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style Provider fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style Redis fill:#ff6b6b,stroke:#fa5252,color:#fff
    style CloudflareR2 fill:#ff6b6b,stroke:#fa5252,color:#fff
```

Gau CDN Service provides static image serving from Cloudflare R2 storage. The service uses Redis as a cache layer with LRU strategy to reduce access frequency to object storage. On request, the service checks the cache first, and only fetches from Cloudflare R2 on cache miss, then stores in cache. The service is completely stateless and can scale horizontally.

---

## Gau Upload Service

```mermaid
graph TB
    subgraph External["Internal Services"]
        InternalClient[Internal Service Clients<br/>Account Service]
    end

    subgraph UploadService["Gau Upload Service"]
        Router[HTTP Router<br/>Gin Framework]
        Middleware[Middlewares<br/>Private Key Validation]
        Controller[Controllers<br/>Upload Handler]
        Repository[Repository Layer<br/>File Operations]
        Provider[Provider Layer<br/>Logger, Validators]
    end

    subgraph Infrastructure["Infrastructure"]
        CloudflareR2[(Cloudflare R2<br/>Object Storage)]
        Logger[Logger Client<br/>Grafana OTLP]
    end

    InternalClient -->|PATCH /api/v2/upload/image<br/>Private-Key Header<br/>Multipart Form Data| Router
    Router --> Middleware
    Middleware --> Controller
    Controller --> Repository
    Controller --> Provider
    
    Provider -->|Validate File<br/>Type, Size, Format| Controller
    Repository -->|Upload Binary| CloudflareR2
    CloudflareR2 -->|File Path| Repository
    
    Controller --> Logger

    style Router fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style Controller fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style Repository fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style Provider fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style CloudflareR2 fill:#ff6b6b,stroke:#fa5252,color:#fff
```

Gau Upload Service handles file uploads to Cloudflare R2 object storage. The service only accepts requests from internal services through Private Key validation. It validates file type, size, and format before uploading, ensuring only valid files within configured size limits are accepted. The service returns the file path upon successful upload.

---

## Gau Email Service

```mermaid
graph TB
    subgraph External["External Services"]
        Producer[Message Producers<br/>Other Services]
        SMTP[SMTP Server<br/>Gmail/Custom]
    end

    subgraph EmailService["Gau Email Service"]
        Consumer[RabbitMQ Consumer<br/>Message Handler]
        Service[Email Service<br/>Template Engine, Sender]
        Logger[Logger Client<br/>Grafana OTLP]
    end

    subgraph Infrastructure["Infrastructure"]
        RabbitMQ[RabbitMQ<br/>Message Queue<br/>Exchange: email_exchange<br/>Queue: email_queue<br/>Routing: email.*]
    end

    Producer -->|Publish Message<br/>Email Template & Data| RabbitMQ
    RabbitMQ -->|Consume Message<br/>Prefetch: 1| Consumer
    Consumer --> Service
    
    Service -->|Parse & Validate| Service
    Service -->|Render Template| Service
    Service -->|Send Email<br/>TLS Connection| SMTP
    
    SMTP -->|Success| Service
    Service -->|ACK Message| RabbitMQ
    
    SMTP -->|Failure| Service
    Service -->|NACK & Requeue<br/>Max Retries: 3| RabbitMQ
    
    Consumer --> Logger
    Service --> Logger

    style Consumer fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style Service fill:#4dabf7,stroke:#1c7ed6,color:#fff
    style RabbitMQ fill:#ff6b6b,stroke:#fa5252,color:#fff
```

Gau Email Service operates as a consumer, listening to messages from the RabbitMQ queue. The service receives email templates and data, renders templates, and sends emails via SMTP server. It implements a retry mechanism with a maximum of 3 retries per message. On success, messages are ACKed; on failure, messages are NACKed and requeued for retry. The service is completely asynchronous and does not block other operations.

---

## Resource Summary

### Resource Allocation By Service

| Service | PostgreSQL | Redis | RabbitMQ | Cloudflare R2 | SMTP | External APIs | Grafana OTLP |
|---------|-----------|-------|----------|---------------|------|---------------|--------------|
| Gau Account Service | Dedicated via PgPool | N/A | N/A | N/A | N/A | Google OAuth | Shared |
| Gau Authorization Service | Dedicated via PgPool | Dedicated | N/A | N/A | N/A | N/A | Shared |
| Gau CDN Service | N/A | Dedicated | N/A | Shared | N/A | N/A | Shared |
| Gau Upload Service | N/A | N/A | N/A | Shared | N/A | N/A | Shared |
| Gau Email Service | N/A | N/A | Dedicated Consumer | N/A | Gmail/Custom | N/A | Shared |

### Service Dependencies

| Service | Calls Services | Called By Services |
|---------|----------------|-------------------|
| Gau Account Service | Gau Authorization Service, Gau Upload Service | N/A (Entry Point) |
| Gau Authorization Service | N/A | Gau Account Service, Gau Kanban Service |
| Gau CDN Service | N/A | N/A (Public Endpoint) |
| Gau Upload Service | N/A | Gau Account Service |
| Gau Email Service | N/A | N/A (Consumer Only) |

---

## Deployment Information

### Kubernetes Configuration
- **Orchestration**: Kubernetes
- **Ingress Controller**: Traefik
- **Routing Strategy**: Path-based routing with annotations
- **Deployment Strategy**: Rolling update
- **Auto Scaling**: Horizontal Pod Autoscaler (HPA) configured

### Security
- **Internal Communication**: Private Key validation between services
- **External Access**: JWT token authentication
- **Secret Management**: Kubernetes Secrets and ConfigMaps
- **TLS/SSL**: Handled at Traefik ingress layer

### Observability
- **Logging**: Centralized logging with Grafana OTLP
- **Metrics**: OpenTelemetry metrics sent to Grafana
- **Tracing**: Distributed tracing support
- **Service Name**: Each service has its own service name in Grafana

### Scalability
- **Stateless Services**: All services are stateless and can scale horizontally
- **Connection Pooling**: PgPool manages PostgreSQL connections efficiently
- **Caching Layer**: Redis reduces load on database and object storage
- **Message Queue**: RabbitMQ allows asynchronous task processing
- **Object Storage**: Cloudflare R2 with Redis cache for serving static content

---

## Architecture Notes

### Shared Resources
- **PgPool**: PostgreSQL connection pooler for efficient connection management
- **Cloudflare R2**: Object storage for images and files, cached by Redis
- **Grafana OTLP**: Observability platform for all services

### Dedicated Resources
- **PostgreSQL Databases**: Each service has its own database to ensure data isolation
- **Redis Instances**: Authorization service uses it for token bitmap, CDN service for image cache
- **RabbitMQ Queue**: Dedicated for Email service consumer

### Communication Patterns
- **Synchronous**: HTTP/HTTPS for inter-service communication
- **Asynchronous**: RabbitMQ message queue for email processing
- **Caching**: Redis to reduce latency and backend system load

### Design Principles
- **Microservices Architecture**: Each service has distinct responsibilities
- **Service Independence**: Services can be deployed and scaled independently
- **Data Isolation**: Each service manages its own data
- **API Gateway Pattern**: Traefik serves as the single entry point
- **CQRS**: Separation of read and write operations in some services
