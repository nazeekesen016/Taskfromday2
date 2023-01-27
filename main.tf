terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.51.0"
    }
  }
  backend "s3" {
    bucket = "globaluniquename"
    key    = "foldervscode/li"
    region = "eu-west-1"
  }
}






resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/18"
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.my-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "main2" {
  vpc_id     = aws_vpc.my-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-west-1b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "main3" {
  vpc_id     = aws_vpc.my-vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "eu-west-1c"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my-vpc.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" { 
  subnet_id      = aws_subnet.main.id 
  route_table_id = aws_route_table.rt.id 
}
resource "aws_route_table_association" "b" { 
  subnet_id      = aws_subnet.main2.id 
  route_table_id = aws_route_table.rt.id 
}
resource "aws_route_table_association" "c" { 
  subnet_id      = aws_subnet.main3.id 
  route_table_id = aws_route_table.rt.id 
}
resource "aws_launch_template" "template" {
  name = "launch-template"
  image_id = "ami-0cb28ea0477916126"
  instance_type = "t3.micro"
  user_data = base64encode("#!/bin/bash \nsudo su \napt install apache2 -y \nsystemctl enable apache2 -y \nsystemctl start apache2 -y \necho \"Hello, World!\" > /var/www/html/index.html")
  network_interfaces { 
    associate_public_ip_address = true 
    security_groups = [aws_security_group.value.id] 
 
  }
}

resource "aws_security_group" "value" {
  name        = "WebServer Security Group"
  vpc_id      = aws_vpc.my-vpc.id 

  dynamic "ingress" { 
    for_each = [80, 443]
    content {
      from_port = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
}
  dynamic "egress" {
    for_each = [0]
    content {
      from_port   = egress.value
      to_port     = egress.value
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
   
  }

  tags = {
    Name  = "Web Server SecurityGroup"
    Owner = "Nazik"
  }
}


# resource "aws_security_group" "security_kylych" {
#   name        = "allow_tls"
#   vpc_id      = aws_vpc.akzhol.id
#   dynamic "ingress" {
#     for_each = [ "80","22" ]
#     content {
#     description      = "inbound"
#     from_port        = ingress.value
#     to_port          = ingress.value
#     protocol         = "tcp"
# }
    
#   }
# }


resource "aws_autoscaling_group" "asg" {
  name                      = "foobar3-terraform-test"
  max_size                  = 4
  min_size                  = 2
  #health_check_grace_period = 300
  #health_check_type         = "ELB"
  desired_capacity          = 3
  force_delete              = true
  target_group_arns = [aws_lb_target_group.test1.id]
  launch_template {
  id      = aws_launch_template.template.id
  }
  vpc_zone_identifier       = [aws_subnet.main.id, aws_subnet.main2.id, aws_subnet.main3.id]
}
# resource "aws_autoscaling_attachment" "asg_attachment_bar" {
#   autoscaling_group_name = aws_autoscaling_group.asg.id
#   lb_target_group_arn    = aws_lb_target_group.test1.arn
# }


resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.value.id]
  subnets = [aws_subnet.main.id, aws_subnet.main2.id, aws_subnet.main3.id]
  tags = {
    Environment = "production"
  }
}
  
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.test.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test1.arn
  }

}
resource "aws_lb_target_group" "test1" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my-vpc.id
}
