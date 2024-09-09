terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-west-1"
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}


resource "aws_subnet" "internal" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-west-1a"  # Adjust to your preferred zone
}

resource "aws_security_group" "cloudnsg" {
  name        = "cloud-nsg"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5986
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = [var.cloud_shell_source]
  }

  ingress {
    from_port   = 8172
    to_port     = 8172
    protocol    = "tcp"
    cidr_blocks = [var.management_ip]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.management_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2_ssm_role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_role.name
}


# EC2 Instances
resource "aws_instance" "cloudVMs" {
  count               = 2
  ami                 = "ami-0dc2d3e4c0f9ebd18"  # Your Windows AMI
  instance_type       = "t2.micro"
  subnet_id           = aws_subnet.internal.id
  vpc_security_group_ids = [aws_security_group.cloudnsg.id]
  key_name            = var.key_name
  availability_zone   = "us-west-1a"
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "cloudvm-${count.index}"
  }
}

resource "aws_eip" "vmIps" {
  count = 2
  instance = aws_instance.cloudVMs[count.index].id
  
}

resource "aws_lb" "LB" {
  name               = "cloud-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.cloudnsg.id]
  subnets            = [aws_subnet.internal.id]
}

resource "aws_lb_target_group" "be_pool" {
  name     = "target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "frontend_listener" {
  load_balancer_arn = aws_lb.LB.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.be_pool.arn
  }
}

resource "aws_lb_target_group_attachment" "be_assoc" {
  count            = 2
  target_group_arn = aws_lb_target_group.be_pool.arn
  target_id        = aws_instance.cloudVMs[count.index].id
  port             = 80
}

resource "aws_ssm_document" "enable_winrm" {
  name          = "EnableWinRM"
  document_type = "Command"

  content = <<EOF
{
  "schemaVersion": "2.2",
  "description": "Enable WinRM for Ansible",
  "parameters": {},
  "mainSteps": [
    {
      "action": "aws:runPowerShellScript",
      "name": "configureWinRM",
      "inputs": {
        "runCommand": [
          "winrm quickconfig -q",
          "winrm set winrm/config/service @{AllowUnencrypted=\"true\"}",
          "winrm set winrm/config/service/auth @{Basic=\"true\"}",
          "winrm set winrm/config/listener?Address=*+Transport=HTTP @{Port=\"5985\"}",
          "netsh advfirewall firewall add rule name=\"WinRM HTTP\" dir=in action=allow protocol=TCP localport=5985"
        ]
      }
    }
  ]
}
EOF
}


resource "aws_ssm_association" "enable_winrm" {
  count            = 2
  name             = aws_ssm_document.enable_winrm.name
  document_version = "$LATEST"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.cloudVMs[count.index].id]
  }
}


output "VMIps" {
  value = aws_eip.vmIps.*.public_ip
}

output "Load_Balancer_IP" {
  value = aws_lb.LB.dns_name
}
