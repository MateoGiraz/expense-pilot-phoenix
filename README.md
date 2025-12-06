ExpensePilot
============

Credentials for Login
---------------------
```
admin@saas.com
Password1
```
Architecture Overview
---------------------

We've evolved our monolithic application into a distributed system composed of several microservices, each dedicated to specific business logic. Our **Phoenix application** remains the core user interface, interacting with these microservices via an **API Gateway**.

Currently, our system includes the following services:

*   **Auth Service** (Node)
    
*   **Audit Service** (Rails)
    
*   **Expenses Service** (Go)
    
*   **Notifications Service** (Python)
    

### Infrastructure

Our infrastructure is hosted on **Amazon Web Services (AWS)**, specifically utilizing an **Amazon ECS cluster** for container orchestration. Each application is **dockerized** and deployed as an independent service within this cluster. To ensure data isolation, every application has its own dedicated **Amazon RDS database instance**. All these ECS and RDS instances reside securely within a **Virtual Private Cloud (VPC)**.

### Monitoring & Logging

For comprehensive monitoring and centralized logging, we use **New Relic**. All applications are configured to report logs and vital statistics to New Relic, providing deep visibility into our system's performance and health.

### CI/CD Pipelines

Our development workflow is streamlined with **GitHub Actions**. We have integrated pipelines that automate both the execution of our unit tests and the entire deployment process, ensuring rapid and reliable delivery of new features and updates.

Running Locally with Docker Compose
-----------------------------------

To run all microservices locally, you'll need **Docker** and **Docker Compose** installed on your machine.

1.  **Environment Variables**:
    
    *   Create a .env file in the **root of the project**.
        
    *   **Please consult another developer** to get the complete list of required variables and their values.
        
2.  **Start Services**:
    
    *   docker-compose up --build


### Deploy

Create and push a new tag, which will trigger the pipeline

`git tag {servicio}-v{version} && git push origin {servicio}-v{version}`
