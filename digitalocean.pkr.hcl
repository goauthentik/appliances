packer {
  required_plugins {
    digitalocean = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/digitalocean"
    }
  }
}

variable "do_token" {
  type      = string
  default   = env("DIGITALOCEAN_TOKEN")
  sensitive = true
}

variable "authentik_version" {
  type    = string
  default = env("AUTHENTIK_VERSION")
}

locals {
  timestamp  = regex_replace(timestamp(), "[- TZ:]", "")
  image_name = "authentik-${replace(var.authentik_version, ".", "-")}"
}

source "digitalocean" "build_droplet" {
  api_token     = var.do_token
  image         = "ubuntu-22-04-x64"
  region        = "nyc3"
  size          = "s-1vcpu-2gb"
  snapshot_name = local.image_name
  droplet_name  = "authentik-${replace(var.authentik_version, ".", "-")}-build-${local.timestamp}"
  ssh_username  = "root"
  tags          = ["authentik", "build", var.authentik_version]
}

build {
  sources = ["source.digitalocean.build_droplet"]

  provisioner "shell" {
    inline = ["cloud-init status --wait"]
  }
  provisioner "ansible" {
    playbook_file = "./site.yaml"
    command       = "./vendor/ansible-wrapper.sh"
    extra_arguments = [
      "--diff",
      "-e", "authentik_version=${var.authentik_version}",
      "-e", "appliance_vendor=digitalocean",
    ]
  }
  provisioner "shell" {
    scripts = [
      "vendor/digitalocean/90-cleanup.sh",
      "vendor/digitalocean/99-img-check.sh",
    ]
  }
}
