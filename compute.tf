data "aws_ami" "server_ami" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "random_id" "green_node_id" {
  byte_length = 2
  count       = var.main_instance_count
}

resource "aws_key_pair" "green_auth" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_instance" "green_main" {
  count                  = var.main_instance_count
  instance_type          = var.main_instance_type
  ami                    = data.aws_ami.server_ami.id
  key_name               = aws_key_pair.green_auth.id
  vpc_security_group_ids = [aws_security_group.green_sg.id]
  subnet_id              = aws_subnet.green_public_subnet[count.index].id
  user_data              = templatefile("./main-userdata.tpl", { new_hostname = "green-main-${random_id.green_node_id[count.index].dec}" })
  root_block_device {
    volume_size = var.main_vol_size
  }

  tags = {
    Name = "green-main-${random_id.green_node_id[count.index].dec}"
  }

  #Don't use provisioners unless it's the last resort. It's also not stored in the state.
  provisioner "local-exec" {
    command = "printf '\n${self.public_ip}' >> aws_hosts"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "sed -i '/^[0-9]/d' aws_hosts"
  }
}

# #DON'T USE THIS. It doesn't wait for Grafana to be bootstrapped.
# resource "null_resource" "grafana_update" {
#   count = var.main_instance_count
#   provisioner "remote-exec" {
#     inline = ["sudo apt upgrade -y grafana && touch upgrade.log && echo 'I upgraded Grafana' >> upgrade.log"]

#     connection {
#       type        = "ssh"
#       user        = "ubuntu"
#       private_key = file("/home/ubuntu/.ssh/id_rsa")
#       host        = aws_instance.green_main[count.index].public_ip
#     }
#   }
# }