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

variable "local_build" {
  type        = bool
  default     = false
  description = "Set to true for local builds to enable SSH compatibility options"
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

variable "ssh_bastion_host" {
  type        = string
  default     = ""
  description = "Bastion/jump host for SSH access to OpenStack instances"
}

variable "ssh_bastion_username" {
  type        = string
  default     = ""
  description = "Username for bastion host authentication"
}

variable "ssh_bastion_port" {
  type        = number
  default     = 22
  description = "SSH port on bastion host"
}

variable "ssh_bastion_agent_auth" {
  type        = bool
  default     = true
  description = "Use SSH agent for bastion authentication"
}

variable "ssh_bastion_private_key_file" {
  type        = string
  default     = ""
  description = "Path to SSH private key file for bastion authentication"
}

variable "ssh_bastion_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Password for bastion host authentication"
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

locals {
  # SSH arguments - Modern algorithms (ed25519, ecdsa) with RSA fallback
  # Prefers modern algorithms but keeps RSA for compatibility
  # Note: ML-KEM (post-quantum) not yet widely available, will add when OpenSSH supports it
  ssh_extra_args = var.local_build ? [
    "--scp-extra-args", "'-O'",
    "--ssh-extra-args",
    "-o IdentitiesOnly=yes -o HostKeyAlgorithms=ssh-ed25519,ecdsa-sha2-nistp256,rsa-sha2-512,rsa-sha2-256 -o PubkeyAcceptedAlgorithms=ssh-ed25519,ecdsa-sha2-nistp256,rsa-sha2-512,rsa-sha2-256"
  ] : [
    "--ssh-extra-args", "-o IdentitiesOnly=yes -o HostKeyAlgorithms=ssh-ed25519,ecdsa-sha2-nistp256,rsa-sha2-512,rsa-sha2-256"
  ]

  # Ansible environment variables - force SCP for local builds to work with bastion
  ansible_env_vars = var.local_build ? [
    "ANSIBLE_NOCOWS=1",
    "ANSIBLE_PIPELINING=True",
    "ANSIBLE_HOST_KEY_CHECKING=False",
    "ANSIBLE_SCP_IF_SSH=True",
    "ANSIBLE_ROLES_PATH=${var.ansible_roles_path}",
    "ANSIBLE_CALLBACK_WHITELIST=profile_tasks",
    "ANSIBLE_STDOUT_CALLBACK=debug"
  ] : [
    "ANSIBLE_NOCOWS=1",
    "ANSIBLE_PIPELINING=False",
    "ANSIBLE_HOST_KEY_CHECKING=False",
    "ANSIBLE_ROLES_PATH=${var.ansible_roles_path}",
    "ANSIBLE_CALLBACK_WHITELIST=profile_tasks",
    "ANSIBLE_STDOUT_CALLBACK=debug"
  ]
}

source "docker" "robot" {
  changes = ["ENTRYPOINT [\"\"]", "CMD [\"\"]"]
  commit  = true
  image   = "${var.docker_source_image}"
}

source "openstack" "robot" {
  flavor            = "${var.flavor}"
  image_disk_format = "${var.vm_image_disk_format}"
  image_name        = "ZZCI - ${var.distro} - robot - ${var.arch} - ${legacy_isotime("20060102-150405.000")}"
  instance_name     = "${var.distro}-robot-${uuidv4()}"
  metadata = {
    ci_managed = "yes"
  }
  networks                      = var.cloud_network != null ? ["${var.cloud_network}"] : null
  region                        = "${var.cloud_region}"
  source_image_name             = "${var.base_image}"
  ssh_proxy_host                = "${var.ssh_proxy_host}"
  ssh_bastion_host              = var.ssh_bastion_host != "" ? var.ssh_bastion_host : null
  ssh_bastion_username          = var.ssh_bastion_username != "" ? var.ssh_bastion_username : null
  ssh_bastion_port              = var.ssh_bastion_port
  ssh_bastion_agent_auth        = var.ssh_bastion_agent_auth
  ssh_bastion_private_key_file  = var.ssh_bastion_private_key_file != "" ? var.ssh_bastion_private_key_file : null
  ssh_bastion_password          = var.ssh_bastion_password != "" ? var.ssh_bastion_password : null
  ssh_username                  = "${var.ssh_user}"
  use_blockstorage_volume       = "${var.vm_use_block_storage}"
  user_data_file                = "${var.cloud_user_data}"
  volume_size                   = "${var.vm_volume_size}"
}

build {
  sources = ["source.docker.robot", "source.openstack.robot"]

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; if [ \"$UID\" == \"0\" ]; then {{ .Vars }} '{{ .Path }}'; else {{ .Vars }} sudo -E '{{ .Path }}'; fi"
    scripts         = ["common-packer/provision/install-python.sh"]
  }

  provisioner "shell-local" {
    command = "./common-packer/ansible-galaxy.sh ${var.ansible_roles_path}"
  }

  provisioner "ansible" {
    ansible_env_vars   = local.ansible_env_vars
    command            = "./common-packer/ansible-playbook.sh"
    extra_arguments    = local.ssh_extra_args
    playbook_file      = "provision/robot.yaml"
    skip_version_check = true
  }
}
