region             = "us-west-1"              # Equivalent to "location" in Azure
vpc_cidr           = "10.0.0.0/16"            # CIDR block for your VPC
subnet_cidr        = "10.0.2.0/24"            # CIDR block for the subnet
key_name           = "my-aws-key"             # SSH key pair name
cloud_shell_source = "0.0.0.0/0"              # Equivalent to source IP range (adjust as necessary)
management_ip      = "0.0.0.0/0"         # IP for RDP or SSH access to the instances
