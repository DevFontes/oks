resource "aws_route53_record" "k3s" {
  zone_id = var.route53_zone_id
  name    = "${var.k3s_api_dns}.${var.domain}"
  type    = "A"
  ttl     = 60
  records = [
    oci_core_instance.k3s_server.public_ip,
    oci_core_instance.k3s_nodes[0].public_ip,
    oci_core_instance.k3s_nodes[1].public_ip,
  ]
}