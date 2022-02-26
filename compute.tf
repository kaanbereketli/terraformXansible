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
#  user_data              = templatefile("./main-userdata.tpl", { new_hostname = "green-main-${random_id.green_node_id[count.index].dec}" })
  root_block_device {
    volume_size = var.main_vol_size
  }

  tags = {
    Name = "green-main-${random_id.green_node_id[count.index].dec}"
  }

  #Don't use provisioners unless it's the last resort. It's also not stored in the state.
  #Here, we add the IP to the aws_hosts file and then make sure that the instance state is OK (initialized and ready to SSh), so ansible doesn't fail.
  provisioner "local-exec" {
    command = "printf '\n${self.public_ip}' >> aws_hosts && aws ec2 wait instance-status-ok --instance-ids ${self.id} --region us-west-1"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "sed -i '/^[0-9]/d' aws_hosts"
  }
}

resource "null_resource" "grafana_install" {
  #We don't specify any counts here. So it will wait all the green_main intances are created.
  depends_on = [aws_instance.green_main]
  provisioner "local-exec" {
    command = "ansible-playbook -i aws_hosts --key-file /home/ubuntu/.ssh/id_rsa playbooks/grafana.yml"
  }
}

output "grafana_access" {
  value = {for i in aws_instance.green_main[*] : i.tags.Name => "${i.public_ip}:3000"}
}