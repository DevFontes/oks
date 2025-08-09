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
    user_data           = base64encode(data.template_file.server_cloud_init.rendered)
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

resource "null_resource" "get_kubeconfig" {
  depends_on = [oci_core_instance.k3s_nodes]

  connection {
    host        = oci_core_instance.k3s_server.public_ip
    user        = "opc"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo cp /etc/rancher/k3s/k3s.yaml /tmp/kubeconfig",
      "sudo chown opc:opc /tmp/kubeconfig"
    ]
  }

  provisioner "local-exec" {
    command = "scp -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no opc@${oci_core_instance.k3s_server.public_ip}:/tmp/kubeconfig ./kubeconfig"
  }

  provisioner "local-exec" {
    command = <<-EOT
      sed -i 's|server: https://127.0.0.1:6443|server: https://${var.k3s_api_dns}.${var.domain}:6443|g' kubeconfig
      sed -i 's|name: default|name: k3s-oci|g' kubeconfig
      sed -i 's|cluster: default|cluster: k3s-oci|g' kubeconfig
      sed -i 's|current-context: default|current-context: k3s-oci|g' kubeconfig
      sed -i 's|user: default|user: k3s-oci|g' kubeconfig
    EOT
  }

  provisioner "local-exec" {
    command = "rm -f ./node-token"
  }
}

data "template_file" "server_cloud_init" {
  template = file("${path.module}/cloud-init/server.yaml.tpl")
  vars = {
    k3s_api_dns = var.k3s_api_dns
    domain      = var.domain
  }
}

data "template_file" "join_cloud_init" {
  count    = 3
  template = file("${path.module}/cloud-init/join.yaml.tpl")
  vars = {
    k3s_token   = trimspace(data.local_file.k3s_token.content)
    server_ip   = oci_core_instance.k3s_server.private_ip
    k3s_api_dns = var.k3s_api_dns
    domain      = var.domain
    join_delay  = count.index * 60  # 0s, 60s, 120s delay
  }
}

data "template_file" "worker_cloud_init" {
  template = file("${path.module}/cloud-init/worker.yaml.tpl")
  vars = {
    k3s_token   = trimspace(data.local_file.k3s_token.content)
    server_ip   = oci_core_instance.k3s_server.private_ip
    k3s_api_dns = var.k3s_api_dns
    domain      = var.domain
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
      count.index == 2 ? data.template_file.worker_cloud_init.rendered : data.template_file.join_cloud_init[count.index].rendered
    )
  }
  depends_on = [data.local_file.k3s_token]
}