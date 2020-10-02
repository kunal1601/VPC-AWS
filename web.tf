provider "aws" {
  region  = "ap-south-1"
  profile = "web"
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "aws_key" {
  key_name   = "mykey1"
  public_key = tls_private_key.key.public_key_openssh
}

resource "local_file" "mykey" {
    content  = tls_private_key.key.private_key_pem
    filename = "C:/Users/nrung/Downloads/mykey1.pem"
}

resource "aws_security_group" "security" {
  name        = "security"
  description = "Allowing ssh and ips to access"

  ingress {
    description = "allowing_ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allowing_http"
    from_port   = 80
    to_port     = 80
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
    Name = "allowing_httpd_ssh"
  }
}

// resource "null_resource" "nulllocal0"  {
//  depends_on = [
//  local_file.mykey
//  ]
//   provisioner "local-exec" {
//            command = "chmod 400 C:/Users/nrung/Downloads/mykey1.pem"
//        }
// }

resource "aws_instance" "webos" {
  ami           = "ami-052c08d70def0ac62"
  instance_type = "t2.micro"
  key_name = "mykey"
//  security_groups = [ "allowing_httpd_ssh" ]
  vpc_security_group_ids = ["${aws_security_group.security.id}"]

  connection {
	type = "ssh"
	user = "ec2-user"
	private_key = file("C:/Users/nrung/Downloads/mykey1.pem")
	host = aws_instance.webos.public_ip
}
  provisioner "remote-exec" {
    inline = [
	"sudo yum install httpd php git -y",
	"sudo systemctl restart httpd",
	"sudo systemctl enable httpd",
     ]
}

  tags = {
    Name = "myos"
  }
}

resource "aws_ebs_volume" "ebs" {
  availability_zone = aws_instance.webos.availability_zone
  size              = 1

  tags = {
    Name = "ebs1"
  }
}

resource "aws_volume_attachment" "attach_ebs" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.ebs.id}"
  instance_id = "${aws_instance.webos.id}"
  force_detach = true
}

resource "null_resource" "null1" {

depends_on = [ 
	aws_volume_attachment.attach_ebs
   ]

connection {
	type = "ssh"

	user = "ec2-user"
	private_key = file("C:/Users/nrung/Downloads/mykey1.pem")
	host = aws_instance.webos.public_ip
}
  provisioner "remote-exec" {
    inline = [
	"sudo mkfs.ext4 /dev/xvdh",
	"sudo mount /dev/xvdh  /var/www/html",
	"sudo rm -rf /var/www/html*",
	"sudo git clone https://github.com/AshuRungta/web.git /var/www/html"
     ]
}
}

resource "aws_s3_bucket" "mybucket" {
  bucket = "web"
  acl    = "public-read"

  tags = {
    Name        = "s3bucket"
  }
}

resource "aws_s3_bucket_object" "bucket_object" {
  depends_on = [ aws_s3_bucket.mybucket, ]
  bucket = "web"
  key    = "524827.jpg"
  source = "C:/Users/nrung/Downloads/524827.jpg"
  acl = "public-read"
}


locals {
  s3_origin_id = "s3web"
}



resource "aws_cloudfront_origin_access_identity" "origin_id" {
  comment = "my origin access id"
}

resource "aws_cloudfront_distribution" "s3_distribution" {

  depends_on = [ aws_cloudfront_origin_access_identity.origin_id
  ]

  origin {
    domain_name = aws_s3_bucket.mybucket.bucket_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_id.cloudfront_access_identity_path
    }
  }

    connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/nrung/Downloads/mykey1.pem")
    host     = aws_instance.webos.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo su << EOF",
      "echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.bucket_object.key}'>\" >> /var/www/html/web.html",
      "EOF"
    ]
  }


  enabled             = true
  is_ipv6_enabled     = true

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    viewer_protocol_policy = "redirect-to-https"
  }

  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}



output "web_ip" {
  value = aws_instance.webos.public_ip
}



