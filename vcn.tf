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

# resource "oci_core_network_security_group" "nsg" {
#   compartment_id = var.compartment_id
#   vcn_id         = oci_core_vcn.main.id
#   display_name   = "k3s-nsg"
# }

# resource "oci_core_network_security_group_security_rule" "ssh_rule" {
#   network_security_group_id = oci_core_network_security_group.nsg.id
#   direction                 = "INGRESS"
#   protocol                  = "6"
#   source                    = var.public_ip
#   source_type               = "CIDR_BLOCK"
#   tcp_options {
#     destination_port_range {
#       min = 22
#       max = 22
#     }
#   }
# }

# resource "oci_core_network_security_group_security_rule" "k8s_api" {
#   network_security_group_id = oci_core_network_security_group.nsg.id
#   direction                 = "INGRESS"
#   protocol                  = "6"
#   source                    = var.public_ip
#   source_type               = "CIDR_BLOCK"

#   tcp_options {
#     destination_port_range {
#       min = 6443
#       max = 6443
#     }
#   }
# }

# resource "oci_core_network_security_group_security_rule" "k8s" {
#   network_security_group_id = oci_core_network_security_group.nsg.id
#   direction                 = "INGRESS"
#   protocol                  = "6"
#   source                    = var.public_ip
#   source_type               = "CIDR_BLOCK"

#   tcp_options {
#     destination_port_range {
#       min = 2380
#       max = 2380
#     }
#   }
# }

# resource "oci_core_network_security_group_security_rule" "k8s_etcd" {
#   network_security_group_id = oci_core_network_security_group.nsg.id
#   direction                 = "INGRESS"
#   protocol                  = "6"
#   source                    = var.public_ip
#   source_type               = "CIDR_BLOCK"

#   tcp_options {
#     destination_port_range {
#       min = 2379
#       max = 2379
#     }
#   }
# }

# resource "oci_core_security_list" "k3s_sec_list" {
#   compartment_id = var.compartment_id
#   vcn_id         = oci_core_vcn.main.id
#   display_name   = "k3s_sec_list"
#   ingress_security_rules {
#     protocol = "6"
#     source   = "0.0.0.0/0"
#     tcp_options {
#       min = 22
#       max = 22
#     }
#   }
#   ingress_security_rules {
#     protocol = "6"
#     source   = "0.0.0.0/0"
#     tcp_options {
#       min = 6443
#       max = 6443
#     }
#   }
#   ingress_security_rules {
#     protocol = "6"
#     source   = "0.0.0.0/0"
#     tcp_options {
#       min = 2380
#       max = 2380
#     }
#   }
#   ingress_security_rules {
#     protocol = "6"
#     source   = "0.0.0.0/0"
#     tcp_options {
#       min = 2379
#       max = 2379
#     }
#   }
#   egress_security_rules {
#     protocol    = "all"
#     destination = "0.0.0.0/0"
#   }
# }
