Networking cost optimisation strategies use gateway endpoints for S3, these are free to use and avoid NAT `gteway costs for traffic, making them an ideal solution for high-volume storage.

Use interface endpoints for other services (ECS, ECR, Redis, RDS) These have an hourly cost but are cheaper than public internet access via NAT Gateway. Availabiity Affinity, configure applications to communicate with endpoints within the same AZ to avoid inter-AZ data transfer charges. 
Gateway Endpoints free, no hourly rate
Interface Endpoints hourly fees ($7.30/month) + data processing ($0.01/GB)

Endpoints were not necessary for the other AWS Services (ACM, Route53)

Security Group Design

The Security Groups are defined in the modules/sec_grps and follow two principles 

ECS tasks are ephermeral. When a task is stopped, scale in or redeployed it loses its network interface and is assign a new IP dynamically. Using SG IDs instead of the (e.g. `10.0.4.0/22`), rules
reference the source security group ID directly which provided stricter control for internal service-to-service communication.

The second principle shells first, rules separate. The Application Security Group and ECS Security Group reference each other, defining rules inline creates a circular dependency that Terraform cannot resolve. All SGs are created
as empty shells first, then rules are attached using the standalone
`aws_vpc_security_group_ingress_rule` and `aws_vpc_security_group_egress_rule`
resources. This eliminates the cycle at the graph level.

## Security Group Design

Security groups are defined in `modules/sec_grps` and follow two principles:

**Principle 1 — SG-to-SG references over CIDR ranges**

Rather than allowing traffic from a CIDR block (e.g. `10.0.4.0/22`), rules
reference the source security group ID directly. This means the rule tracks
the *identity* of the resource, not its IP address — important when ECS
assigns IPs dynamically per task.

**Principle 2 — Shells first, rules separate**

Because the ALB SG and ECS SG reference each other, defining rules inline
creates a circular dependency Terraform cannot resolve. All SGs are created
as empty shells first, then rules are attached using the standalone
`aws_vpc_security_group_ingress_rule` and `aws_vpc_security_group_egress_rule`
resources. This eliminates the cycle at the graph level.
