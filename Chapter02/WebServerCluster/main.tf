provider "aws" {
  region = "eu-central-1"
}

variable "server_port" {
  default = 8080
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
    filter {
        name = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}

output "alb_dns_name" {
    value = aws_lb.example.dns_name
    description = "Der Domainname des Application Load Balancers"
}

resource "aws_launch_configuration" "example" {
    image_id = "ami-0faab6bdbac9486fb"
    instance_type = "t2.micro"
    security_groups = [aws_security_group.instance.id]

    user_data = <<-EOF
                #!/bin/bash
                echo "Hello, World" > index.html
                nohup busybox httpd -f -p ${var.server_port} &
                EOF

    # Erforderlich beim Einsatz einer Startkonfiguration zusammen mit einer 
    # Auto Scaling-Gruppe
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_lb" "example" {
    name = "Teffarorm-ASG-Beispiel"
    load_balancer_type = "application"
    subnets = data.aws_subnets.default.ids
    security_groups = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.example.arn
    port = 80
    protocol = "HTTP"

    # Als Standard eine einfache 404 - Seite zurückgeben
    default_action {
        type = "fixed-response"

        fixed_response {
            content_type = "text/plain"
            message_body = "404: Page Not Found"
            status_code = "404"
        }
    }
}

resource "aws_security_group" "instance" {
  name = "terraform-example-http"

  ingress {
    from_port = var.server_port
    to_port = var.server_port
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb" {
    name = "terraform-example-alb"

    # Eingehende HTTP-request zulassen
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # Alle ausgehenden Requests zulassen
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_lb_target_group" "asg" {
    name = "Terraform-ASG-Beispiel"
    port = var.server_port
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default.id

    health_check {
        path = "/"
        protocol = "HTTP"
        matcher = "200"
        interval = 30
        timeout = 3
        healthy_threshold = 2
        unhealthy_threshold = 2
    }
}

resource "aws_lb_listener_rule" "asg" {
    listener_arn = aws_lb_listener.http.arn
    priority = 100

    condition {
        path_pattern {
            values = ["*"]
        }
    }
    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.asg.arn
    }
}

resource "aws_autoscaling_group" "example" {
    launch_configuration = aws_launch_configuration.example.name

    vpc_zone_identifier = data.aws_subnets.default.ids

    target_group_arns = [aws_lb_target_group.asg.arn]
    health_check_type = "ELB"

    # Die Anzahl der Instanzen, die die Auto Scaling-Gruppe starten soll
    min_size = 2
    max_size = 10

    tag {
        key = "Name"
        value = "Terraform-ASG-Beispiel"
        propagate_at_launch = true
    }
}