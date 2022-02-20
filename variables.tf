variable vpc_cidr {
    type = string
    default = "10.124.0.0/16"
}

variable access_ip {
    type = string
    default = "0.0.0.0/0"
}

variable main_instance_type {
    type = string
    default = "t2.micro"
}

variable main_vol_size {
    type = number
    default = 8
}

#Change this to add more EC2 instances. There is a count in the instance resource.
variable main_instance_count {
    type = number
    default = 1
}