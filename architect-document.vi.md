# Kiến Trúc Hệ Thống Gau Backend Microservices

## Sơ Đồ Tổng Quan Hệ Thống

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

Sơ đồ tổng quan mô tả kiến trúc microservices được triển khai trên Kubernetes Cluster. Client gửi request qua Traefik Ingress Controller, được định tuyến đến các microservices tương ứng. Hệ thống sử dụng kết hợp tài nguyên dùng chung (PgPool, Cloudflare R2, Grafana) và tài nguyên riêng cho từng service (PostgreSQL databases, Redis instances, RabbitMQ). Tất cả services đều gửi metrics và logs về Grafana để monitoring.

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

Gau Account Service quản lý tài khoản người dùng, xử lý đăng ký, đăng nhập, quản lý profile và MFA. Service kết nối với PostgreSQL database riêng qua PgPool để lưu trữ thông tin người dùng. Service tích hợp với Gau Authorization Service để quản lý token, Gau Upload Service để xử lý upload avatar, và Google OAuth API cho chức năng SSO. Tất cả hoạt động được ghi log về Grafana.

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

Gau Authorization Service chịu trách nhiệm quản lý token và phân quyền trong hệ thống. Service sử dụng Private Key để xác thực request từ các internal services. Service kết nối với PostgreSQL database riêng để lưu trữ refresh tokens và Redis riêng để quản lý token bitmap, cho phép revoke tokens nhanh chóng. Tất cả token operations đều được log về Grafana.

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

Gau CDN Service cung cấp chức năng serve static images từ Cloudflare R2 storage. Service sử dụng Redis làm cache layer với LRU strategy để giảm số lần truy cập vào object storage. Khi có request, service kiểm tra cache trước, nếu cache miss mới fetch từ Cloudflare R2 và lưu vào cache. Service hoàn toàn stateless và có thể scale horizontal.

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

Gau Upload Service xử lý upload file lên Cloudflare R2 object storage. Service chỉ nhận request từ các internal services thông qua Private Key validation. Service validate file type, size và format trước khi upload, đảm bảo chỉ accept các file hợp lệ với size limit được cấu hình. Service trả về file path sau khi upload thành công.

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

Gau Email Service hoạt động như một consumer, lắng nghe messages từ RabbitMQ queue. Service nhận email templates và data, render template và gửi email qua SMTP server. Service implement retry mechanism với maximum 3 retries cho mỗi message. Nếu gửi thành công, message được ACK, nếu thất bại message sẽ được NACK và requeue để retry. Service hoàn toàn asynchronous, không block các operations khác.

---

## Tổng Hợp Tài Nguyên

### Bảng Tài Nguyên Theo Service

| Service | PostgreSQL | Redis | RabbitMQ | Cloudflare R2 | SMTP | External APIs | Grafana OTLP |
|---------|-----------|-------|----------|---------------|------|---------------|--------------|
| Gau Account Service | Dedicated via PgPool | N/A | N/A | N/A | N/A | Google OAuth | Shared |
| Gau Authorization Service | Dedicated via PgPool | Dedicated | N/A | N/A | N/A | N/A | Shared |
| Gau CDN Service | N/A | Dedicated | N/A | Shared | N/A | N/A | Shared |
| Gau Upload Service | N/A | N/A | N/A | Shared | N/A | N/A | Shared |
| Gau Email Service | N/A | N/A | Dedicated Consumer | N/A | Gmail/Custom | N/A | Shared |

### Bảng Kết Nối Giữa Các Services

| Service | Gọi Đến Services | Được Gọi Bởi Services |
|---------|-----------------|---------------------|
| Gau Account Service | Gau Authorization Service, Gau Upload Service | N/A (Entry Point) |
| Gau Authorization Service | N/A | Gau Account Service, Gau Kanban Service |
| Gau CDN Service | N/A | N/A (Public Endpoint) |
| Gau Upload Service | N/A | Gau Account Service |
| Gau Email Service | N/A | N/A (Consumer Only) |

---

## Thông Tin Triển Khai

### Kubernetes Configuration
- **Orchestration**: Kubernetes
- **Ingress Controller**: Traefik
- **Routing Strategy**: Path-based routing với annotations
- **Deployment Strategy**: Rolling update
- **Auto Scaling**: Horizontal Pod Autoscaler (HPA) được cấu hình

### Security
- **Internal Communication**: Private Key validation giữa các services
- **External Access**: JWT token authentication
- **Secret Management**: Kubernetes Secrets và ConfigMaps
- **TLS/SSL**: Được xử lý tại Traefik ingress layer

### Observability
- **Logging**: Centralized logging với Grafana OTLP
- **Metrics**: OpenTelemetry metrics được gửi về Grafana
- **Tracing**: Distributed tracing support
- **Service Name**: Mỗi service có service name riêng trong Grafana

### Scalability
- **Stateless Services**: Tất cả services đều stateless, có thể scale horizontal
- **Connection Pooling**: PgPool quản lý PostgreSQL connections hiệu quả
- **Caching Layer**: Redis giảm tải cho database và object storage
- **Message Queue**: RabbitMQ cho phép xử lý asynchronous tasks
- **Object Storage**: Cloudflare R2 với Redis cache để serve static content

---

## Ghi Chú Kiến Trúc

### Tài Nguyên Dùng Chung
- **PgPool**: PostgreSQL connection pooler, giúp quản lý connections hiệu quả
- **Cloudflare R2**: Object storage cho images và files, được cache bởi Redis
- **Grafana OTLP**: Observability platform cho tất cả services

### Tài Nguyên Riêng
- **PostgreSQL Databases**: Mỗi service có database riêng để đảm bảo data isolation
- **Redis Instances**: Authorization service dùng cho token bitmap, CDN service dùng cho image cache
- **RabbitMQ Queue**: Dedicated cho Email service consumer

### Communication Patterns
- **Synchronous**: HTTP/HTTPS cho inter-service communication
- **Asynchronous**: RabbitMQ message queue cho email processing
- **Caching**: Redis để giảm latency và tải cho backend systems

### Design Principles
- **Microservices Architecture**: Mỗi service có responsibility riêng biệt
- **Service Independence**: Services có thể deploy và scale độc lập
- **Data Isolation**: Mỗi service quản lý data riêng
- **API Gateway Pattern**: Traefik làm single entry point
- **CQRS**: Separation of read và write operations ở một số services
