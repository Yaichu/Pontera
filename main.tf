provider "aws" {
  region = ""
  access_key = ""
  secret_key = ""
}

data "aws_route53_zone" "primary" {
  name = "pontera.com"
}

resource "aws_vpc" "vpc" {
  count = length(var.regions)

  cidr_block = {
    "us-east-2" = "10.0.0.0/16"
    "us-west-2" = "172.16.0.0/16"
  }[var.regions[count.index]]

  tags = {
    "us-east-2" = {
      Name = "vpc-east"
    }
    "us-west-2" = {
      Name = "vpc-west"
    }
  }[var.regions[count.index]]

  vpc_id = var.vpc_ids[var.regions[count.index]]
}

resource "aws_subnet" "private_subnet" {
  count = length(var.regions)

  vpc_id              = aws_vpc.vpc[count.index].id
  availability_zone = var.availability_zones[var.regions[count.index]][count.index]

  tags = {
    "us-east-2" = {
      Name = "subnet1-aza"
    }
    "us-west-2" = {
      Name = "subnet1-azb"
    }
  }[var.regions[count.index]]
}

resource "aws_security_group" "haproxy" {
  count = length(var.regions)

  description = "HAproxy Security Group"
  vpc_id      = aws_vpc.vpc[count.index].id

  tags = {
    "us-east-2" = {
      Name = "sg-haproxy-east"
    }
    "us-west-2" = {
      Name = "sg-haproxy-west"
    }
  }[var.regions[count.index]]
}

resource "aws_s3_bucket" "haproxy_access_logs" {
  count = length(var.regions)

  bucket = {
    "us-east-2" = "haproxy-access-logs-east"
    "us-west-2" = "haproxy-access-logs-west"
  }[var.regions[count.index]]

  tags = {
    "us-east-2" = {
      Name = "haproxy-access-logs-east"
    }
    "us-west-2" = {
      Name = "haproxy-access-logs-west"
    }
  }[var.regions[count.index]]
}

# Network LB

resource "aws_lb" "network_lb" {
  internal           = true
  load_balancer_type = "network"
  subnets            = [
    aws_subnet.private_subnet[count.index].id,  # subnet1-aza
    aws_subnet.private_subnet[count.index + 1].id,  # subnet1-azb
  ]

  access_logs {
    bucket = aws_s3_bucket.haproxy_access_logs[count.index].id  # Relevant S3 bucket for region us-east-2
  }

  ip_address_type = "ipv4"
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "lb-haproxy"
  }
}


resource "aws_lb_listener" "network_listener" {
  load_balancer_arn = aws_lb.network_lb.arn
  port              = 6090
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.haproxy_tg.arn
  }
}

resource "aws_lb_target_group" "haproxy_tg" {
  name     = "tg-haprpxy"
  port     = 6090
  protocol = "TCP"
  vpc_id   = aws_vpc.vpc[count.index].id  # VPC ID based on region
  preserve_client_ip = false

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 10
    
  }

  stickiness {
    enabled          = true
    type             = "lb_cookie"
    cookie_duration  = 3600
  }
}

# EC2 Instances

resource "aws_instance" "instance1" {
  ami           = var.server1ami
  instance_type = var.server1type
  subnet_id     = aws_subnet.private_subnet[count.index].id # subnet1-aza
  vpc_security_group_ids = [
    aws_security_group.haproxy.id,
  ]
  tags = {
    Name = "haproxy-1-prod-aza"
    ENV  = "production"
  }

  user_data = <<-EOF
    #!/bin/bash -xe
    exec > >(tee /var/log/user-data.log|logger -t user-data -s) 2>&1

    date
    echo
    whoami

  EOF
}

resource "aws_instance" "instance2" {
  ami           = var.server2ami
  instance_type = var.server2type
  subnet_id     = aws_subnet.private_subnet[count.index + 1].id # subnet1-azb
  vpc_security_group_ids = [
    aws_security_group.haproxy.id,
  ]
  tags = {
    Name = "haproxy-2-prod-azb"
    ENV  = "production"
  }

  user_data = <<-EOF
    #!/bin/bash -xe
    exec > >(tee /var/log/user-data.log|logger -t user-data -s) 2>&1

    date
    echo
    whoami

    
  EOF
}

resource "aws_route53_record" "haproxy_lb" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "haproxy.pontera.internal"
  type    = "CNAME"
  ttl     = 300
  records = [aws_lb.lb-haproxy.dns_name]
}

resource "aws_route53_record" "haproxy1_instance" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "haproxy1.pontera.internal"
  type    = "A"
  ttl     = 300
  records = [aws_instance.haproxy1.private_ip]
  weight  = 0
  set_identifier = "us-east-2"
}

resource "aws_route53_record" "haproxy2_instance" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "haproxy2.pontera.internal"
  type    = "A"
  ttl     = 300
  records = [aws_instance.haproxy2.private_ip]
  weight  = 0
  set_identifier = "us-west-2"
}
