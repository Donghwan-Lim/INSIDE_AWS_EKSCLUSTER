variable "region" {
  type        = string
  default     = "ap-northeast-2"
  description = "Provision Target Resion in AWS Cloud"
}

variable "instnace_type" {
  type    = string
  default = "t2.micro"
}