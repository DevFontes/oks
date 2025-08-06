resource "oci_load_balancer_load_balancer" "k3s_lb" {
  compartment_id = var.compartment_id
  display_name   = "k3s-lb"
  shape          = "flexible"
  subnet_ids     = [ oci_core_subnet.public_subnet.id ]

  shape_details {
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 10
  }

  is_private = false
}

resource "oci_load_balancer_backend_set" "k3s_backend_http" {
  name             = "k3s-http"
  load_balancer_id = oci_load_balancer_load_balancer.k3s_lb.id
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol = "HTTP"
    url_path = "/"
    port     = 80
  }
}

resource "oci_load_balancer_listener" "http" {
  load_balancer_id = oci_load_balancer_load_balancer.k3s_lb.id
  name             = "http"
  default_backend_set_name = oci_load_balancer_backend_set.k3s_backend_http.name
  port             = 80
  protocol         = "HTTP"
}

resource "oci_load_balancer_backend" "server_1" {
  backendset_name  = oci_load_balancer_backend_set.k3s_backend_http.name
  load_balancer_id = oci_load_balancer_load_balancer.k3s_lb.id
  ip_address       = oci_core_instance.k3s_server.private_ip
  port             = 80
  weight           = 1
}

resource "oci_load_balancer_backend" "server_2" {
  backendset_name  = oci_load_balancer_backend_set.k3s_backend_http.name
  load_balancer_id = oci_load_balancer_load_balancer.k3s_lb.id
  ip_address       = oci_core_instance.k3s_nodes[0].private_ip
  port             = 80
  weight           = 1
}

resource "oci_load_balancer_backend" "server_3" {
  backendset_name  = oci_load_balancer_backend_set.k3s_backend_http.name
  load_balancer_id = oci_load_balancer_load_balancer.k3s_lb.id
  ip_address       = oci_core_instance.k3s_nodes[1].private_ip
  port             = 80
  weight           = 1
}