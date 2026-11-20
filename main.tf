terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get default VPC subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Get latest Ubuntu 24.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create EC2 instance
resource "aws_instance" "monitoring" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = sort(data.aws_subnets.default.ids)[0]

  monitoring = true

  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    echo "CPU load test starting" > /tmp/cpu-test.log
 
    sleep 120
 
    timeout 600 bash -c 'while true; do :; done' || true
 
    echo "CPU load test completed" >> /tmp/cpu-test.log
  EOF

  tags = {
    Name        = "Sriram-project3-ec2"
    Project     = "EC2-CloudWatch-Monitoring"
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}

# CloudWatch CPU alarm
resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name        = "Sriram-project3-high-cpu"
  alarm_description = "Alarm when EC2 CPU utilization exceeds 20 percent"

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2

  metric_name = "CPUUtilization"
  namespace   = "AWS/EC2"

  period    = 60
  statistic = "Average"
  threshold = 20

  dimensions = {
    InstanceId = aws_instance.monitoring.id
  }

  treat_missing_data = "notBreaching"
  actions_enabled    = false
}

# Terraform outputs
output "instance_id" {
  value = aws_instance.monitoring.id
}

output "public_ip" {
  value = aws_instance.monitoring.public_ip
}

output "alarm_name" {
  value = aws_cloudwatch_metric_alarm.cpu_alarm.alarm_name
}
