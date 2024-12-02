terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "eu-north-1"
}
######################  VPC and SUBNETS ######################
resource "aws_vpc" "commit_vpc" {
  cidr_block = "14.0.0.0/16"
  enable_dns_support = true

  tags = {
    Project = "commit"
  }
}

resource "aws_subnet" "commit_subnet1" {
  vpc_id = aws_vpc.commit_vpc.id
  cidr_block = "14.0.1.0/24"
  availability_zone = "eu-north-1a"
  map_public_ip_on_launch = true

  tags = {
    Project = "commit"
  }
}

resource "aws_subnet" "commit_subnet2" {
  vpc_id = aws_vpc.commit_vpc.id
  cidr_block = "14.0.2.0/24"
  availability_zone = "eu-north-1b"
  map_public_ip_on_launch = true


  tags = {
    Project = "commit"
  }
}

resource "aws_internet_gateway" "commit_internet_gateway" {
  vpc_id = aws_vpc.commit_vpc.id
  
  tags = {
    Project = "commit"
  }
}

resource "aws_default_route_table" "aws_route_table" {
  default_route_table_id  = aws_vpc.commit_vpc.default_route_table_id

  route {
    cidr_block = "14.0.0.0/16"
    gateway_id = "local"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.commit_internet_gateway.id
  }  

  tags = {
    Project = "commit"
  }
}
######################  Security groups ######################
resource "aws_security_group" "commit_security_group" {
  name = "commit_security_group"
  description = "Allow all traffic out. Allow HTTP/S and 3000-32767 traffic in"
  vpc_id = aws_vpc.commit_vpc.id

  tags = {
    Project = "commit"
  }
}

resource "aws_vpc_security_group_egress_rule" "commit_sg_egress" {
  security_group_id = aws_security_group.commit_security_group.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "-1"  
}

resource "aws_vpc_security_group_ingress_rule" "commit_sg_ingress_public" {
  security_group_id = aws_security_group.commit_security_group.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "tcp"
  to_port = 443
  from_port = 443
}

resource "aws_vpc_security_group_ingress_rule" "commit_sg_ingress_public_http" {
  security_group_id = aws_security_group.commit_security_group.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "tcp"
  to_port = 80
  from_port = 80
}

resource "aws_vpc_security_group_ingress_rule" "commit_sg_ingress_public_node_port" {
  security_group_id = aws_security_group.commit_security_group.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "tcp"
  to_port = 32767
  from_port = 30000
}
######################  EKS Cluster ######################
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "commit_eks_iam_role" {
  name               = "commit-eks-cluster-iam-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "commit_eks_iam_role_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.commit_eks_iam_role.name
}

resource "aws_eks_cluster" "commit_eks" {
  name     = "commit_eks"
  role_arn = aws_iam_role.commit_eks_iam_role.arn

  vpc_config {
    subnet_ids = [aws_subnet.commit_subnet1.id, aws_subnet.commit_subnet2.id]
    security_group_ids = [ aws_security_group.commit_security_group.id ]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.commit_eks_iam_role_AmazonEKSClusterPolicy,
  ]
  tags = {
    Project = "commit"
  }
}

output "endpoint" {
  value = aws_eks_cluster.commit_eks.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.commit_eks.certificate_authority[0].data
}

######################  EKS Workers ######################
resource "aws_iam_role" "commit_eks_workers_iam" {
  name = "commit-eks-node-group"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "commit_eks_workers_iam_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.commit_eks_workers_iam.name
}

resource "aws_iam_role_policy_attachment" "commit_eks_workers_iam_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.commit_eks_workers_iam.name
}

resource "aws_iam_role_policy_attachment" "commit_eks_workers_iam_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.commit_eks_workers_iam.name
}

resource "aws_eks_node_group" "commit_eks_workers" {
  cluster_name    = aws_eks_cluster.commit_eks.name
  node_group_name = "commit-eks-workers"
  node_role_arn   = aws_iam_role.commit_eks_workers_iam.arn
  subnet_ids      = [aws_subnet.commit_subnet1.id, aws_subnet.commit_subnet2.id]
  instance_types = ["t3.medium"]
  # remote_access {
  #   ec2_ssh_key = "sandbox_key"
  # }

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.commit_eks_workers_iam_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.commit_eks_workers_iam_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.commit_eks_workers_iam_AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = {
    Project = "commit"
  }
}