output "k3s_node_ips" {
  value = [for instance in oci_core_instance.k3s : instance.public_ip]
}
