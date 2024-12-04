Streaming Application Design Document

1.	Function of the Web App:

The web application is designed to function as a streaming service similar to Netflix. It offers users access to a vast collection of video content, including films, TV series, and documentaries. The service includes features such as user account management, tailored content suggestions, and high-quality video streaming. It is built to support at least 500 daily users, with a focus on scalability and robustness to accommodate future growth.

2. Architecture Diagram:
<img width="468" alt="image" src="https://github.com/user-attachments/assets/a8cde04e-2d00-45bf-977d-26cffbf224b6">

VPC (Virtual Private Cloud):

•	Global Services:
o	Route 53: Domain Name System (DNS) resolution, directing user traffic globally.
o	CloudFront: Content delivery network, serving cached content from the nearest edge location.

•	Public Subnet:
o	Cognito: User authentication and management, with Multi-Factor Authentication (MFA) for enhanced security.
o	S3: Storage for static media files.
o	Internet Gateway: Provides internet connectivity for the public subnet.
o	NAT Gateway: Facilitates secure internet access for instances in the private subnet.
o	API Gateway: Manages and secures API requests.

•	Private Subnet:
o	Elastic Load Balancer (ELB): Distributes traffic to EC2 instances; public-facing part is in the public subnet, backend instances are in the private subnet.
o	Auto Scaling Group: Manages multiple EC2 instances for scalability.
o	EC2 Instances: Hosts the application services.
o	RDS (Relational Database Service): Stores relational data.
o	ElastiCache (Redis): Provides caching for frequently accessed data.
o	S3: Additional storage and backups.

•	Security and Monitoring:
o	IAM (Identity and Access Management): Secures access to AWS services and resources
o	CloudWatch: Monitoring and logging service

3. Resilience and Performance Requirements:

Elasticity:
•	Auto Scaling: Automatically adjusts the number of running EC2 instances based on demand.
•	CloudFront: Brings content closer to users, effectively managing varying traffic loads.

Auto Recovery:
•	Monitoring and Alerts: Amazon CloudWatch offers real-time monitoring and automated recovery processes.

Failure Isolation:
•	Multi-AZ Deployment: Services are spread across multiple availability zones.
•	Circuit Breakers: Implemented in microservices to handle partial failures gracefully.
•	Redundant Components: Multiple load balancers, NAT Gateways, and database replicas ensure high availability.

4. Performance Requirements Calculations:
User Data:
•	Current User Base: 500 users
•	Future User Base Projections:
o	3 months: 500 * (1 + 0.10)/3 = 665 users
o	6 months: 500 * (1 + 0.10)/6 = 886 users
o	12 months: 500 * (1 + 0.10)/12 = 1569 users
•	Average Size of Request: 1 MB
•	Peak Hours: 6 PM to 10 PM
•	Average Number of Requests per Day per User: 20
•	Seasonal Variance: 20% increase during holidays

Storage Data:
•	Number of Reads and Writes per Day: 20 requests/user * 500 users = 10,000 requests
•	Average Size of Read/Write Request: 1 MB
•	Estimated Storage Size: 10,000 MB/day ≈ 10 GB/day
•	Retention Policy: 30 days
•	Storage Performance Requirements: High throughput, low latency

Database Requirements:
•	Transactions Per Second: 10,000 requests/day ÷ 24 hours ÷ 60 minutes ÷ 60 seconds ≈ 0.116 TPS
•	Read Write Ratio: 80:20
•	Query Complexity: Moderate
•	Indexing and Caching: Redis for caching frequent queries

Bandwidth Requirements:
•	Data Ingress and Egress: 10 GB/day
•	Latency Expectations: <100 ms for critical operations
•	Network Traffic Patterns: High during peak hours

5. Secure Architecture Considerations:

CNAS-1: Insecure Cloud, Container, or Orchestration Configuration
•	Component: S3 Bucket
•	Enabled versioning and deletion protection, added strict access policies.

CNAS-2: Injection Flaws (Application Layer, Cloud Events, Cloud Services)
•	Component: Application Logic
•	Sanitized all user inputs, shifted logic away from frontend to backend.

CNAS-3: Insufficient Identity and Access Management (IAM)
•	Component: IAM Policies
•	Applied least privilege principle, enforced Multi-Factor Authentication (MFA) for critical access.

CNAS-5: Insecure Data Storage and Transfers
•	Component: Data Storage and Transmission
•	Enabled encryption for data at rest and in transit using AWS Key Management Service (KMS) and TLS/SSL.

CNAS-6: Insecure API Endpointsjk
•	Component: API Gateway
•	Implemented rate limiting, API keys, and OAuth 2.0 authentication for securing API endpoints.

CNAS-9: Insufficient Logging and Monitoring
•	Component: Logging and Monitoring
•	Enhanced logging and monitoring with CloudWatch, set up alerts for suspicious activities.

6. Cost Optimization:

1. Networking (VPC)
•	Single NAT Gateway: Reduces costs by using one NAT Gateway for all subnets.
•	NAT Instance for Development: More affordable alternative to NAT Gateway for non-production environments.

2. Compute (EC2)
•	t3.micro Instances: Free-tier eligible, minimizing EC2 costs for small workloads.
•	Auto-Stop: Automates stopping instances during off-hours, saving on compute charges.
•	Spot Instances: Saves up to 90% for flexible workloads.

3. Storage (S3)
•	S3 Intelligent-Tiering: Automatically moves objects to cheaper storage tiers.
•	Lifecycle Rules: Move data to S3 Glacier after 30 days and delete it after a year to minimize storage costs.
•	CloudFront: Reduces data transfer costs by caching content at edge locations.

4. Database (RDS)
•	db.t3.micro: Free-tier eligible for development workloads.
•	Storage Autoscaling: Only pay for the storage you actually use.
•	Short Backup Retention: Reduces backup storage costs by keeping backups for a shorter period.

5. Caching (ElastiCache)
•	t3.micro Nodes: Cost-effective for development and light caching needs.
•	Short Cache TTLs: Reduces memory usage by automatically clearing expired cache data.

6. Monitoring (CloudWatch)
•	Short Log Retention: Reduces log storage costs by keeping logs for a limited period.
•	Basic Monitoring: Use basic monitoring instead of detailed metrics to save on CloudWatch charges.

7. IAM (Roles and Permissions)
•	Least Privilege: Restricting access minimizes unnecessary resource usage and API calls, reducing costs.

8. DNS (Route 53)
•	Avoid Route 53 in Development: Use CloudFront URLs or EC2 public IPs instead of paying for DNS management.


Final Architecture deployment 

Git Repository link: https://github.com/SheetalYadav01/Netflix-like-Applicaton


Screenshots

<img width="468" alt="image" src="https://github.com/user-attachments/assets/bfb3249b-fa46-4a3a-ada3-1e7bc83f221f">
<img width="468" alt="image" src="https://github.com/user-attachments/assets/7ff05fea-1707-45fd-bbad-01d43595495b">
<img width="468" alt="image" src="https://github.com/user-attachments/assets/1376fb14-a53a-4c66-bdb1-9c8712c43159">
<img width="468" alt="image" src="https://github.com/user-attachments/assets/2bb685af-7c7f-4706-8bb6-31900cd06cba">
<img width="468" alt="image" src="https://github.com/user-attachments/assets/9cc9cafe-ee6e-499a-9c26-00b8acfdb861">
<img width="468" alt="image" src="https://github.com/user-attachments/assets/8b9d6eb6-3283-43e1-b59c-c54446f3eed5">
<img width="468" alt="image" src="https://github.com/user-attachments/assets/c48e70ce-a183-4145-89af-9941783cd7f1">
<img width="468" alt="image" src="https://github.com/user-attachments/assets/ceb769d9-dbe2-43ad-90ca-9fe71ff3bef9">
<img width="468" alt="image" src="https://github.com/user-attachments/assets/aca98f50-e832-45d1-8751-f553e5eb81ee">
<img width="468" alt="image" src="https://github.com/user-attachments/assets/54cbc945-280e-4bdf-a7d0-6c606d7dea0f">
<img width="468" alt="image" src="https://github.com/user-attachments/assets/a2ad01ce-5340-49e8-9145-1ef898f13731">
<img width="468" alt="image" src="https://github.com/user-attachments/assets/ea6ea7ae-7974-48f8-b531-0650bb999e7a">
<img width="468" alt="image" src="https://github.com/user-attachments/assets/59f90f92-f296-4f88-a7c5-c7541af6000f">
<img width="468" alt="image" src="https://github.com/user-attachments/assets/97906107-7607-4e5f-9747-a4544236fcdf">
<img width="468" alt="image" src="https://github.com/user-attachments/assets/d80c8d84-d1fa-4ac1-b61e-aac48dca61cc">
<img width="468" alt="image" src="https://github.com/user-attachments/assets/3d15947b-a902-435a-aa2e-eb7243cb2b40">
<img width="468" alt="image" src="https://github.com/user-attachments/assets/541447e2-3fd7-4884-9211-f6a4a963478d">
<img width="468" alt="image" src="https://github.com/user-attachments/assets/9e07e4df-1763-4e12-84c2-68da05cea840">
<img width="468" alt="image" src="https://github.com/user-attachments/assets/b185617e-14b3-473a-9736-1ebc54c01cdf">
<img width="468" alt="image" src="https://github.com/user-attachments/assets/553c1e4d-5d57-4380-b437-b22e6840f3e0">
















 

 



 


 


 


 


 

 


 


 


 


 


 


 


 


 


 



 


 

 
![image](https://github.com/user-attachments/assets/8e324349-32d8-421e-a1b3-af7407b8c819)
