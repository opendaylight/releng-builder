packer {
  required_plugins {
    openstack = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/openstack"
    }
  }
}
variable "ansible_roles_path" {
  type    = string
  default = ".galaxy"
}

variable "arch" {
  type    = string
  default = "x86_64"
}

variable "base_image" {
  type = string
  default = null
}

variable "cloud_network" {
  type = string
  default = null
}

variable "cloud_region" {
  type    = string
  default = "ca-ymq-1"
}

variable "cloud_auth_url" {
  type    = string
  default = null
}

variable "cloud_tenant" {
  type    = string
  default = null
}

variable "cloud_user" {
  type    = string
  default = null
}

variable "cloud_pass" {
  type    = string
  default = null
}

variable "cloud_user_data" {
  type = string
  default = null
}

variable "distro" {
  type = string
  default = null
}

variable "docker_source_image" {
  type = string
  default = null
}

variable "flavor" {
  type    = string
  default = "v3-standard-2"
}

variable "ssh_proxy_host" {
  type    = string
  default = ""
}

variable "source_ami_filter_name" {
  type    = string
  default = null
}

variable "source_ami_filter_product_code" {
  type    = string
  default = null
}

variable "source_ami_filter_owner" {
  type    = string
  default = null
}

variable "ssh_user" {
  type = string
}

variable "vm_image_disk_format" {
  type    = string
  default = ""
}

variable "vm_use_block_storage" {
  type    = string
  default = "true"
}

variable "vm_volume_size" {
  type    = string
  default = "20"
}

source "docker" "mininet-ovs-28" {
  changes = ["ENTRYPOINT [\"\"]", "CMD [\"\"]"]
  commit  = true
  image   = "${var.docker_source_image}"
}

source "openstack" "mininet-ovs-28" {
  flavor            = "${var.flavor}"
  image_disk_format = "${var.vm_image_disk_format}"
  image_name        = "ZZCI - ${var.distro} - mininet-ovs-28 - ${var.arch} - ${legacy_isotime("20060102-150405.000")}"
  instance_name     = "${var.distro}-mininet-ovs-28-${uuidv4()}"
  metadata = {
    ci_managed = "yes"
  }
  networks                = ["${var.cloud_network}"]
  region                  = "${var.cloud_region}"
  source_image_name       = "${var.base_image}"
  ssh_proxy_host          = "${var.ssh_proxy_host}"
  ssh_username            = "${var.ssh_user}"
  use_blockstorage_volume = "${var.vm_use_block_storage}"
  user_data_file          = "${var.cloud_user_data}"
  volume_size             = "${var.vm_volume_size}"
}

build {
  sources = ["source.docker.mininet-ovs-28", "source.openstack.mininet-ovs-28"]

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; if [ \"$UID\" == \"0\" ]; then {{ .Vars }} '{{ .Path }}'; else {{ .Vars }} sudo -E '{{ .Path }}'; fi"
    scripts         = ["common-packer/provision/install-python.sh"]
  }

  provisioner "shell-local" {
    command = "./common-packer/ansible-galaxy.sh ${var.ansible_roles_path}"
  }

  provisioner "ansible" {
    ansible_env_vars   = [
        "ANSIBLE_NOCOWS=1",
        "ANSIBLE_PIPELINING=False",
        "ANSIBLE_HOST_KEY_CHECKING=False",
        "ANSIBLE_ROLES_PATH=${var.ansible_roles_path}",
        "ANSIBLE_CALLBACK_WHITELIST=profile_tasks",
        "ANSIBLE_STDOUT_CALLBACK=debug"
    ]
    command            = "./common-packer/ansible-playbook.sh"
    extra_arguments    = [
        "--ssh-extra-args", "-o IdentitiesOnly=yes -o HostKeyAlgorithms=+ssh-rsa"
    ]
    playbook_file      = "provision/mininet-ovs-2.8.yaml"
    skip_version_check = true
  }
}
