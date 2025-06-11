resource "oci_core_vcn" "main" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.compartment_id
  display_name   = "k3s-vcn"

  dns_label     = "k3s"
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
  cidr_block              = "10.0.10.0/24"
  compartment_id          = var.compartment_id
  vcn_id                  = oci_core_vcn.main.id
  display_name            = "k3s-public-subnet"
  route_table_id          = oci_core_route_table.rt.id
  prohibit_public_ip_on_vnic = false
  dns_label               = "k3s"
}

resource "oci_core_network_security_group" "nsg" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "k3s-nsg"
}

resource "oci_core_network_security_group_security_rule" "ssh_rule" {
  network_security_group_id = oci_core_network_security_group.nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
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
  protocol                  = "6" # TCP
  source                    = var.public_ip
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

resource "oci_core_instance" "k3s" {
  count               = 4
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  shape               = "VM.Standard.A1.Flex"
  display_name        = "k3s-node-${count.index + 1}"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ampere.images[0].id
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.public_subnet.id
    assign_public_ip          = true
    nsg_ids                   = [oci_core_network_security_group.nsg.id]
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    # user_data           = base64encode(file("cloud-init/${count.index < 3 ? "server" : "worker"}.yaml"))
    user_data = base64encode(
      file("cloud-init/${
        count.index == 0 ? "server" :
        (count.index == 1 || count.index == 2 ? "join" : "worker")
      }.yaml")
    )
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
