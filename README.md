### Collection of Terraforms

#### Setup
```
export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id) && \
export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
```

#### Initialized
```
terraform init
```

#### Format .tf File
```
terraform fmt
```

#### Validate
```
terraform validate
```

#### Create Resources
```
terraform apply
```

#### Remove Resources
```
terraform destroy
```

#### Import from AWS
```
terraform import aws_s3_bucket.example <bucket_name>
aws_s3_bucket=the resource type
.example=name from the .tf file
```

#### Note
<p>
The Terraform state file (terraform.tfstate) contains information about the infrastructure managed by Terraform, including the resources it created, their current state, and metadata. This information is sensitive because it can be used to access and manipulate the underlying infrastructure, which may contain sensitive data or control critical systems. As such, it is important to secure the Terraform state file by keeping it confidential and protecting it from unauthorized access or modification. This can be achieved by using version control systems, backing up the state file, and using Terraform's remote state functionality to store it securely in a centralized location.
</p>


```

provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "bucket" {
  bucket = "example-bucket"
}

resource "aws_cloudfront_distribution" "distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket.bucket_domain_name
    origin_id   = "S3-${aws_s3_bucket.bucket.bucket_name}"

    s3_origin_config {
      region = "us-west-2"
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.bucket.bucket_name}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
  }

  viewer_certificate {
    acm_certificate_arn = "arn:aws:acm:us-west-2:111122223333:certificate/12345678-1234-1234-1234-123456789012"
    ssl_support_method  = "sni-only"
  }

  enabled = true
}

```