
resource "aws_vpc" "mytf" {
  cidr_block = var.cidr
}


resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.mytf.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.mytf.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}
resource "aws_internet_gateway" "myigw" {
  vpc_id = aws_vpc.mytf.id
}
resource "aws_route_table" "myrt" {
  vpc_id = aws_vpc.mytf.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myigw.id
  }
}
resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.myrt.id

}
resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.myrt.id

}
resource "aws_security_group" "mysg" {
  name   = "mysg"
  vpc_id = aws_vpc.mytf.id
  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my-sg"
  }
}
resource "aws_s3_bucket" "mys3" {
  bucket = "tformganesh20252210"
}
resource "aws_s3_bucket_ownership_controls" "mys3" {
  bucket = aws_s3_bucket.mys3.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "mys3" {
  bucket = aws_s3_bucket.mys3.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "mys3" {
  depends_on = [
    aws_s3_bucket_ownership_controls.mys3,
    aws_s3_bucket_public_access_block.mys3,
  ]

  bucket = aws_s3_bucket.mys3.id
  acl    = "public-read"
}
resource "aws_instance" "web1" {
  ami                    = "ami-0360c520857e3138f"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.mysg.id]
  subnet_id              = aws_subnet.sub1.id
  user_data_base64       = base64encode(file("userdata.sh"))
}
resource "aws_instance" "web2" {
  ami                    = "ami-0360c520857e3138f"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.mysg.id]
  subnet_id              = aws_subnet.sub2.id
  user_data_base64       = base64encode(file("userdata1.sh"))
}
resource "aws_lb" "mylb" {
  name               = "mylob"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.mysg.id]
  subnets            = [aws_subnet.sub1.id, aws_subnet.sub2.id]

  tags = {
    Name = "targroup"
  }
}
resource "aws_lb_target_group" "mylbtgp" {
  name     = "mylbtgp"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.mytf.id

  health_check {
    path = "/"
    port = "traffic-port"

  }

}
resource "aws_lb_target_group_attachment" "targ1" {
  target_group_arn = aws_lb_target_group.mylbtgp.arn
  target_id        = aws_instance.web1.id
  port             = 80

}
resource "aws_lb_target_group_attachment" "targ2" {
  target_group_arn = aws_lb_target_group.mylbtgp.arn
  target_id        = aws_instance.web2.id
  port             = 80

}
resource "aws_lb_listener" "listen" {
  load_balancer_arn = aws_lb.mylb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.mylbtgp.arn
    type             = "forward"

  }

}
output "loadbalancerdns" {
  value = aws_lb.mylb.dns_name
}