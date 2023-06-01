The project describes a Terraform code that:

Builds 2 VPCs, one per region: us-east-2, us-west-2. VPC IDs: vpc-east , vpc-west.
in each of these VPCs/Regions the following are defined:
(1) 2 availability zones: aza , azb
(2) Private subnets: subnet1-aza , subnet1-azb
(3) Security Groups named haproxy and their IDs: sg-haproxy-east , sg-haproxy-west.
(4) S3 buckets: haproxy-access-logs-east , haproxy-access-logs-west.

In this case Terraform uses region-based mapping for the relevant described above components.
The components also launch a network LB, Target group, 2 EC2 (ubuntu) instances connected to it and a
few DNS records.

The network LB is configured as follows:
 - It is internal, IPv4
 - Cross-zone that is built on the 2 AZ (subnet1-aza, subnet1-azb)
 - It's name ("Name" tag) is "lb-haproxy"
 - Writes access logs to the relevant S3 bucket
 - The LB listens to TCP/6090 and forwards requests to a Target Group named "tg-haprpxy"
 
  The Target Group has:
  - 2 checks for healthy or unhealthy
  - 10sec timeout + interval
  - Enabled Stickiness
  - Disabled "Preserve client IP addresses"

The 2 EC2 instances attached to the above TG have:
- Haproxy server profile 
- Region-based SG (same for both); one is launched on subnet1-aza, the second is launched on subnet1-azb
- The following tags set:
    Name=haproxy-1-prod-aza or haproxy-2-prod-azb
    ENV= production
- A user-data script attached:
```
#!/bin/bash -xe
exec > >(tee /var/log/user-data.log|logger -t user-data -s) 2>&1

date
echo
whoami
```
The EC2 instances are launched from an AMI given as input parameter; 
their type is provided as an input parameter - both are t3a.small.
(Thus, there are 4 input params: server1ami, server1type, server2ami, server2type)

In addition, the following DNS records are created:
- haproxy.pontera.internal - CNAME to the LB endpoint
- haproxy1.pontera.internal- A record to the haproxy-1-prod-aza instance IP
- haproxy2.pontera.internal- A record to the haproxy-2-prod-azb instance IP

All these DNS records are weighted (0) with the region as the recordID.