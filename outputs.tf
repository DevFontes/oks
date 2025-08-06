output "k3s_server_ip" {
  value = oci_core_instance.k3s_server.public_ip
}

output "k3s_nodes_ips" {
  value = [for instance in oci_core_instance.k3s_nodes : instance.public_ip]
}

output "lb_ip" {
  value = oci_load_balancer_load_balancer.k3s_lb.ip_address_details[0].ip_address
}