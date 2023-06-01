variable "regions" {
  description = "The AWS regions"
  type        = list(string)
  default     = ["us-east-2", "us-west-2"]
}


variable "vpc_ids" {
  description = "Mapped IDs of the VPCs per region"
  type        = map(string)
  default = {
    "us-east-2" = "vpc-east"
    "us-west-2" = "vpc-west"
  }
}


variable "availability_zones" {
  description = "Mapped availability zones in each region"
  type        = map(list(string))
  default = {
    "us-east-2" = ["us-east-2a", "us-east-2b"]
    "us-west-2" = ["us-west-2a", "us-west-2b"]
  }
}

variable "subnet_names" {
  description = "The subnet names"
  type        = list(string)
}

variable "security_group_names" {
  description = "The security group names"
  type        = list(string)
}

variable "s3_bucket_names" {
  description = "The S3 bucket names"
  type        = list(string)
}

variable "server1ami" {
  description = "AMI ID for EC2 instance 1 - haproxy-1-prod-aza"
  type        = string
}

variable "server1type" {
  description = "Instance type for EC2 instance 1"
  type        = string
  default     = "t3a.small"
}

variable "server2ami" {
  description = "AMI ID for EC2 instance 2 - haproxy-2-prod-azb"
  type        = string
}

variable "server2type" {
  description = "Instance type for EC2 instance 2"
  type        = string
  default     = "t3a.small"
}
