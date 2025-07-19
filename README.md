<div style="align-items: center"> Gau Backend Services</div>

This repository contains backend services for the "gau" project, organized as a monorepo with multiple Go microservices and supporting scripts.

## Structure

- Each service is located in its own directory (e.g., `gau-account-service/`, `gau-cdn-service/`, etc.)
- Common scripts for initialization and updates are provided (`init.sh`, `update.sh`)
- Each service contains its own source code, configuration, migrations, and deployment scripts (Docker, Kubernetes)

## Services

Below is a list of services and their main functionalities. This table will be updated as new services are added.

| Service Name              | Description / Main Functions                                          | URL                                                     |
|---------------------------|-----------------------------------------------------------------------|---------------------------------------------------------|
| gau-account-service       | User account management (authentication, registration, profile, etc.) | https://github.com/tnqbao/gau-account-service           |
| gau-authorization-service | Authorization, access control, and token management                   | https://github.com/tnqbao/gau-authorization-service.git |
| gau-cdn-service           | CDN and image management                                              | https://github.com/tnqbao/gau-cdn-service               |
| gau-upload-service        | File and media upload management                                      | https://github.com/tnqbao/gau-upload-service            |
| ...                       | ...                                                                   | ...                                                     |

## Getting Started

### Prerequisites
