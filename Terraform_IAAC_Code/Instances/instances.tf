/*This is the provider block for AWS*/
provider "aws" {
  region = var.region
}

/*This is backend module*/
terraform {
  backend "s3" {}
}

/*This is to fetch the infra data from the infrastructure statefile*/

data "terraform_remote_state" "network_configuration" {
  backend = "s3"

  config = {

    bucket = var.remote_state_bucket
    key    = var.remote_state_key
    region = var.region

  }
}

/*AWS Public security group for the public access where we need to login to EC2 instances and install our packages, Here we are allowing web traffic from anywhere on port 80, SSH traffic only from my desktop IP whereas egress in allowed stateful*/


resource "aws_security_group" "ec2_public_security_group" {
  name = "EC2-Public-SG"
  description = "Internet facing Ec2 Instances"
  vpc_id = data.terraform_remote_state.network_configuration.outputs.vpc_id

  ingress {
    from_port = 80
    protocol  = "TCP"
    to_port   = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    protocol  = "TCP"
    to_port   = 22
    cidr_blocks = ["85.211.16.214/32"]
  }
  egress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

/*AWS Private security group for the backend accessed webservers, Here we are only allowing the traffic from the public SG EC2 instances i.e ec2 from public_security_group, thats when we defined "security_groups = [aws_security_group.ec2_public_security_group.id]" */

resource "aws_security_group" "ec2_private_security_group" {
  name = "Ec2-Private-SG"
  description = "Only Allow public SG resources to access these instances"
  vpc_id = data.terraform_remote_state.network_configuration.outputs.vpc_id

  ingress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0
    security_groups = [aws_security_group.ec2_public_security_group.id]
  }

  ingress {
    from_port = 80
    protocol  = "tcp"
    to_port   = 80
    cidr_blocks = ["0.0.0.0/0"]
    description = "allow health checking for instances using this SG"
  }

  egress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

/*This is internet facing LB, hence we allowed traffic for all*/

resource "aws_security_group" "elb_security_group" {
  name = "ELB-SG"
  description = "elastic load balancer security group"
  vpc_id = data.terraform_remote_state.network_configuration.outputs.vpc_id

  ingress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow web traffic to load balancer"
  }

  egress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

/* This is to fine grain your access, creating the IAM role with "ec2.amazonaws.com" and "application-autoscaling.amazonaws.com" to access whereever it is attached can have access to ec2.amazonaws.com and application-autoscaling.amazonaws.com mentioned resources, This way ASG can launch the Ec2 instances */

resource "aws_iam_role" "ec2_iam_role" {
  name               = "EC2-IAM-Role_lendinvest"
  assume_role_policy = <<EOF
{
    "Version" : "2012-10-17",
    "Statement" :
    [
      {
        "Effect" : "Allow",
        "Principal" : {
           "Service" : ["ec2.amazonaws.com", "application-autoscaling.amazonaws.com"]
        },
        "Action" : "sts:AssumeRole"
      }
    ]
}
   EOF
}

/*The resources these policy is attached can have access to all EC2, elastic load balancer, cloudwatch and logs functionalities*/

resource "aws_iam_role_policy" "ec2_iam_role_policy" {
  name   = "EC2-IAM-Policy-LendInvest"
  role   = aws_iam_role.ec2_iam_role.id
  policy = <<EOF
{
 "Version" : "2012-10-17",
 "Statement" : [
   {
     "Effect": "Allow",
     "Action": [
       "ec2:*",
       "elasticloadbalancing:*",
       "cloudwatch:*",
       "logs:*"
     ],
     "Resource": "*"
    }
   ]
}
EOF
}

/*here we are going to attach the above IAM policy to the IAM role which we have created*/

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "EC2-IAM-Instance-Profile"
  role = aws_iam_role.ec2_iam_role.name
}

/*To pull latest AMI always we need ti configuration*/

data "aws_ami" "launch_configuration_ami" {
  most_recent = true
  owners = ["amazon"]
}

/*whatever the instances which launch through this config will have the below mentioned values, as in instance type, IAM roles and SG*/
resource "aws_launch_configuration" "ec2_private_launch_configuration" {
  image_id                    = "ami-0ca285d4c2cda3300"
  instance_type               = var.ec2_instance_type
  key_name                    = var.key_pair_name
  associate_public_ip_address = false
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  security_groups = [aws_security_group.ec2_private_security_group.id]

  user_data = <<EOF
   #!/bin/bash
   yum update -y
   yum install httpd -y
   service httpd start
   chkconfig httpd on
   export INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)
   echo "<html><body><h1>Hello from LendInvest Backend at instance <b>"$INSTANCE_ID"</b></h1></body></html>" > /var/www/html/index.html

EOF
}

/*whatever the instances which launch through this config will have the below mentioned values, as in instance type, IAM roles and SG*/


resource "aws_launch_configuration" "ec2_public_launch_configuration" {
  image_id                    = "ami-0ca285d4c2cda3300"
  instance_type               = var.ec2_instance_type
  key_name                    = var.key_pair_name
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  security_groups = [aws_security_group.ec2_public_security_group.id]

  user_data = <<EOF
   #!/bin/bash
   yum update -y
   yum install httpd -y
   service httpd start
   chkconfig httpd on
   export INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)
   echo "<html><body><h1>Hello from LendInvest Public facing webapp at instance <b>"$INSTANCE_ID"</b></h1></body></html>" > /var/www/html/index.html

EOF
}

/*Elastic public load balancer for URL access and highly available URL*/
resource "aws_elb" "web_app_load_balancer" {
  name            = "LendInvest-WebApp-LoadBalancer"
  internal        = "false"
  security_groups = [aws_security_group.elb_security_group.id]
  subnets         = [
   data.terraform_remote_state.network_configuration.outputs.public_subnet_1_id,
   data.terraform_remote_state.network_configuration.outputs.public_subnet_2_id,
   data.terraform_remote_state.network_configuration.outputs.public_subnet_3_id
  ]
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  health_check {
    healthy_threshold   = 5
    interval            = 30
    target              = "HTTP:80/index.html"
    timeout             = 10
    unhealthy_threshold = 5
  }
}

/*Back end load balancer and highly available URL */
resource "aws_elb" "backend_load_balancer" {
  name            = "LendInvest-Backend-LoadBalancer"
  internal        = "true"
  security_groups = [aws_security_group.elb_security_group.id]
  subnets         = [
    data.terraform_remote_state.network_configuration.outputs.private_subnet_1_id,
    data.terraform_remote_state.network_configuration.outputs.private_subnet_2_id,
    data.terraform_remote_state.network_configuration.outputs.private_subnet_3_id
  ]
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  health_check {
    healthy_threshold   = 5
    interval            = 30
    target              = "http:80/index.html"
    timeout             = 10
    unhealthy_threshold = 5
  }
}

/*ASG creation for private*/

resource "aws_autoscaling_group" "ec2_private_autoscaling_group" {
  name = "LendInvest_backend_autoscaling_group"
  vpc_zone_identifier = [
    data.terraform_remote_state.network_configuration.outputs.private_subnet_1_id,
    data.terraform_remote_state.network_configuration.outputs.private_subnet_2_id,
    data.terraform_remote_state.network_configuration.outputs.private_subnet_3_id
  ]
  max_size = var.max_instance_size
  min_size = var.min_instance_size

  launch_configuration = aws_launch_configuration.ec2_private_launch_configuration.name
  health_check_type = "ELB"
  load_balancers = [aws_elb.backend_load_balancer.name]
  tag {
    key                 = "Name"
    propagate_at_launch = false
    value               = "Backend-Ec2-Instance"
  }
  tag {
    key                 = "Type"
    propagate_at_launch = false
    value               = "LendInvest"
  }
}

/*Public ASG creation*/
resource "aws_autoscaling_group" "ec2_public_autoscaling_group" {
  name = "LendInvest_web_autoscaling_group"
  vpc_zone_identifier = [
    data.terraform_remote_state.network_configuration.outputs.public_subnet_1_id,
    data.terraform_remote_state.network_configuration.outputs.public_subnet_2_id,
    data.terraform_remote_state.network_configuration.outputs.public_subnet_3_id
  ]

  max_size = var.max_instance_size
  min_size = var.min_instance_size

  launch_configuration = aws_launch_configuration.ec2_public_launch_configuration.name
  health_check_type = "ELB"
  load_balancers = [aws_elb.web_app_load_balancer.name]

  tag {
    key                 = "Name"
    propagate_at_launch = false
    value               = "WebApp-Ec2-Instance"
  }
  tag {
    key                 = "Type"
    propagate_at_launch = false
    value               = "LendInvest"
  }
}

/*Auto scaling policy for public ASG*/
resource "aws_autoscaling_policy" "webapp_LendInvest_scaling_policy" {
  autoscaling_group_name   = aws_autoscaling_group.ec2_public_autoscaling_group.name
  name                     = "LendInvest-WebApp-Policy"
  policy_type              = "TargetTrackingScaling"
  min_adjustment_magnitude = 1

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

/*Auto scaling policy for private ASG*/
resource "aws_autoscaling_policy" "backend_LendInvest_scaling_policy" {
  autoscaling_group_name   = aws_autoscaling_group.ec2_private_autoscaling_group.name
  name                     = "LendInvest-Backend-Policy"
  policy_type              = "TargetTrackingScaling"
  min_adjustment_magnitude = 1

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

/*
resource "aws_sns_topic" "webapp_LendInvest_autoscaling_topic" {
  name = "WebApp-Autoscaling-Topic"
  display_name = "WebApp-Autoscaling-Topic"
}

resource "aws_sns_topic_subscription" "webapp_LendInvest_sns_subscription" {
  endpoint  = "+447850517716"
  protocol  = "sms"
  topic_arn = aws_sns_topic.webapp_LendInvest_autoscaling_topic.arn
}

*/

/*
resource "aws_autoscaling_notification" "webapp_autoscaling_notification" {
  group_names   = [aws_autoscaling_group.ec2_public_autoscaling_group.name]
    notifications = [
   "autoscaling:EC2_INSTANCE_LAUNCH",
   "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR"
  ]
  topic_arn     = aws_sns_topic.webapp_LendInvest_autoscaling_topic.arn
}

*/