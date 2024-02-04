provider "aws" {
  region = "eu-central-1"
}

resource "aws_instance" "first_instance" {
  ami = "ami-0faab6bdbac9486fb"
  instance_type = "t2.micro"

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF

  user_data_replace_on_change = true

  tags = {
      Name = "FirstTerraformInstance"
  }
}

resource "aws_security_group" "allow_http" {
  name = "terraform-example-http"

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}