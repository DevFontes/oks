resource "oci_core_vcn" "main" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.compartment_id
  display_name   = "k3s-vcn"
  dns_label      = "k3s"
  freeform_tags = {
    "CreatedBy" = "Terraform"
  }
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_id
  display_name   = "k3s-igw"
  vcn_id         = oci_core_vcn.main.id
}

resource "oci_core_route_table" "rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "k3s-rt"

  route_rules {
    network_entity_id = oci_core_internet_gateway.igw.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

resource "oci_core_subnet" "public_subnet" {
  cidr_block                 = "10.0.10.0/24"
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.main.id
  display_name               = "k3s-public-subnet"
  route_table_id             = oci_core_route_table.rt.id
  prohibit_public_ip_on_vnic = false
  dns_label                  = "k3s"
}

resource "oci_core_network_security_group" "nsg" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "k3s-nsg"
}

resource "oci_core_network_security_group_security_rule" "ssh_rule" {
  network_security_group_id = oci_core_network_security_group.nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.public_ip
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_network_security_group_security_rule" "k8s_api" {
  network_security_group_id = oci_core_network_security_group.nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.public_ip
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "k8s" {
  network_security_group_id = oci_core_network_security_group.nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.public_ip
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 2380
      max = 2380
    }
  }
}

resource "oci_core_network_security_group_security_rule" "k8s_etcd" {
  network_security_group_id = oci_core_network_security_group.nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.public_ip
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 2379
      max = 2379
    }
  }
}

resource "oci_core_security_list" "k3s_sec_list" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "k3s_sec_list"
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 6443
      max = 6443
    }
  }
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 2380
      max = 2380
    }
  }
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 2379
      max = 2379
    }
  }
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ampere" {
  compartment_id           = var.compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "k3s_server" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  shape               = "VM.Standard.A1.Flex"
  display_name        = "k3s-node-1"
  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }
  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ampere.images[0].id
  }
  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    assign_public_ip = true
    nsg_ids          = [oci_core_network_security_group.nsg.id]
  }
  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    user_data           = base64encode(file("cloud-init/server.yaml"))
  }
}

resource "null_resource" "get_k3s_token" {
  depends_on = [oci_core_instance.k3s_server]

  connection {
    host        = oci_core_instance.k3s_server.public_ip
    user        = "opc"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "for i in {1..60}; do sudo test -s /var/lib/rancher/k3s/server/node-token && echo 'Token encontrado!' && break || (echo 'Aguardando token...'; sleep 10); done",
      "sleep 10",
      "sudo cat /var/lib/rancher/k3s/server/node-token > /tmp/node-token"
    ]
  }

  provisioner "local-exec" {
    command = "scp -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no opc@${oci_core_instance.k3s_server.public_ip}:/tmp/node-token ./node-token"
  }
}

data "local_file" "k3s_token" {
  depends_on = [null_resource.get_k3s_token]
  filename   = "${path.module}/node-token"
}

data "template_file" "join_cloud_init" {
  template = file("${path.module}/cloud-init/join.yaml.tpl")
  vars = {
    k3s_token = trimspace(data.local_file.k3s_token.content)
    server_ip = oci_core_instance.k3s_server.private_ip
  }
}

data "template_file" "worker_cloud_init" {
  template = file("${path.module}/cloud-init/worker.yaml.tpl")
  vars = {
    k3s_token = trimspace(data.local_file.k3s_token.content)
    server_ip = oci_core_instance.k3s_server.private_ip
  }
}

resource "oci_core_instance" "k3s_nodes" {
  count               = 3
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  shape               = "VM.Standard.A1.Flex"
  display_name        = "k3s-node-${count.index + 2}"
  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }
  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ampere.images[0].id
  }
  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    assign_public_ip = true
    nsg_ids          = [oci_core_network_security_group.nsg.id]
  }
  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    user_data = base64encode(
      count.index == 2 ? data.template_file.worker_cloud_init.rendered : data.template_file.join_cloud_init.rendered
    )
  }
  depends_on = [data.local_file.k3s_token]
}