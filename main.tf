resource "yandex_vpc_network" "develop" {
  name = var.vpc_name
}

resource "yandex_vpc_subnet" "develop" {
  name           = var.subnet_name
  zone           = var.default_zone
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = var.default_cidr
}

data "yandex_compute_image" "my_image" {
  family = var.image_family
}

###Cloud init
data "template_file" "cloudinit" {
  template = file("${path.module}/templates/cloud-init.yaml.tpl")

  vars = {
    ssh_key          = var.vms_ssh_root_key,
    uname            = var.vm_user,
    ugroup           = var.vm_u_group,
    shell            = var.vm_u_shell,
    s_com            = join(", ", var.sudo_cloud_init),
    pack             = join("\n  - ", var.pack_list),
    vm_user_password = var.vm_user_password
  }
}

### Massive Install VM Ya-cloud
resource "yandex_compute_instance" "vm" {
  for_each = var.vms_resources

  name        = each.value.name
  platform_id = each.value.platform_id
  zone        = each.value.zone
  hostname    = each.value.hostname

  metadata = {
    user-data          = data.template_file.cloudinit.rendered
    serial-port-enable = 1
  }

  resources {
    cores         = each.value.cores
    memory        = each.value.memory
    core_fraction = each.value.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.my_image.id
      size = each.value.hdd_size
      type = each.value.hdd_type
    }
}

  network_interface {
    subnet_id = yandex_vpc_subnet.develop.id
    nat       = each.value.chose
  }
}

### Wait complite cloud-init
resource "null_resource" "wait_for_cloud_init" {
  for_each = yandex_compute_instance.vm # Откуда беруться значения ip

  provisioner "remote-exec" {
    inline = [
      "while ! cloud-init status --wait >/dev/null; do echo 'Waiting for cloud-init to complete...'; sleep 30; done"
    ]

    connection {
      type     = "ssh"
      host     = each.value.network_interface[0].nat_ip_address # Список ip
      user     = var.vm_user
      private_key = file(var.vms_ssh_root_key_file) 
    }
  }

  depends_on = [yandex_compute_instance.vm]
}

resource "local_file" "ansible_inventory" {
  depends_on = [data.template_file.cloudinit]
  filename = "${path.module}/ansible/inventory/hosts.yaml"
  content  = templatefile("${path.module}/templates/hosts.yaml.tpl", {
    vm_details = yandex_compute_instance.vm
    vm_user    = var.vm_user
  })
}

resource "null_resource" "ansible_apply" {
  provisioner "local-exec" {
    command = <<EOT
      ANSIBLE_CONFIG=ansible/ansible.cfg  ansible-playbook -i ${path.module}/ansible/inventory/hosts.yaml ${path.module}/ansible/playbooks/playbook_roles.yaml
    EOT

    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "false"
    }
  }

  depends_on = [ local_file.ansible_inventory, null_resource.wait_for_cloud_init ]
}
