# Oracle K3s HA Cluster (OKS)

Este projeto cria um cluster **K3s em Alta Disponibilidade** com **4 nodes** na Oracle Cloud Infrastructure (OCI) utilizando **VMs ARM gratuitas**.

## 🏗️ Arquitetura

- **3 Control Planes** (etcd + api-server) para HA
- **1 Worker Node** dedicado para workloads
- **Load Balancer** OCI para distribuição de tráfego
- **DNS externo** via Route53 (AWS) ou outro provider
- **Firewall** automaticamente configurado
- **SSL/TLS** pronto para Let's Encrypt

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   k3s-node-1    │    │   k3s-node-2    │    │   k3s-node-3    │
│ (Control Plane) │    │ (Control Plane) │    │ (Control Plane) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                    │
                          ┌─────────────────┐
                          │   k3s-node-4    │
                          │    (Worker)     │
                          └─────────────────┘
```

## 📋 Pré-requisitos

### 1. Oracle Cloud Infrastructure (OCI)
- Conta OCI ativa (**Pay-as-you-go** necessário para VMs ARM)
- Tenancy, User e Compartment configurados
- Par de chaves SSH gerado

### 2. Amazon Web Services (AWS) - Para DNS
- Conta AWS ativa
- Zona hospedada no Route53 configurada
- Credenciais IAM com permissões Route53

### 3. Ferramentas Locais
```bash
# Instalar Terraform >= 1.0
curl -fsSL https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip -o terraform.zip
unzip terraform.zip && sudo mv terraform /usr/local/bin/

# Instalar kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

## ⚙️ Configuração

### 1. Credenciais OCI

Crie o arquivo `~/.oci/config`:
```ini
[DEFAULT]
user=ocid1.user.oc1..aaaaaaaaa...
fingerprint=aa:bb:cc:dd:ee:ff...
key_file=~/.oci/oci_api_key.pem
tenancy=ocid1.tenancy.oc1..aaaaaaaaa...
region=sa-saopaulo-1
```

### 2. Credenciais AWS (Para Route53)

Configure as variáveis de ambiente:
```bash
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
export AWS_DEFAULT_REGION="us-east-1"
```

### 3. Chaves SSH

```bash
# Gerar par de chaves se não existir
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa

# As chaves devem estar em:
# ~/.ssh/id_rsa (privada)
# ~/.ssh/id_rsa.pub (pública)
```

### 4. Configurar Variáveis

Copie e edite o arquivo de variáveis:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edite `terraform.tfvars`:
```hcl
# === ORACLE CLOUD (OCI) ===
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaaa..."
user_ocid        = "ocid1.user.oc1..aaaaaaaaa..."
fingerprint      = "aa:bb:cc:dd:ee:ff..."
private_key_path = "~/.oci/oci_api_key.pem"
region           = "sa-saopaulo-1"
compartment_id   = "ocid1.compartment.oc1..aaaaaaaaa..."

# === ACESSO SSH ===
ssh_public_key_path  = "~/.ssh/id_rsa.pub"
ssh_private_key_path = "~/.ssh/id_rsa"
public_ip           = "203.0.113.0/32"  # SEU IP público para SSH

# === DNS (AWS Route53) ===
route53_zone_id = "Z1PA6795UKMFR9"  # ID da sua zona no Route53
domain         = "example.com"      # Seu domínio
k3s_api_dns    = "k3s"              # Subdomínio (k3s.example.com)

# === AWS CREDENCIAIS ===
aws_access_key_id     = "AKIAIOSFODNN7EXAMPLE"
aws_secret_access_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
aws_region           = "us-east-1"
```

## 🚀 Instalação

### 1. Preparar o ambiente
```bash
git clone <repository-url>
cd oracle-k3s-ha
terraform init
```

### 2. Verificar o plano
```bash
terraform plan
```

### 3. Aplicar a infraestrutura
```bash
terraform apply
```

**⏱️ Tempo estimado:** 10-15 minutos

### 4. Verificar o cluster
```bash
# Usar o kubeconfig gerado
export KUBECONFIG=./kubeconfig

# Verificar nodes
kubectl get nodes -o wide

# Verificar pods do sistema
kubectl get pods -A
```

## 📁 Estrutura do Projeto

```
oracle-k3s-ha/
├── README.md                 # Esta documentação
├── providers.tf             # Configuração dos providers
├── variables.tf             # Definição das variáveis
├── terraform.tfvars         # Valores das variáveis (criar)
├── compute.tf              # Instâncias e configuração K3s
├── vcn.tf                  # Virtual Cloud Network
├── securit.tf              # Security Groups e regras
├── lb.tf                   # Load Balancer
├── route53.tf              # DNS no Route53
├── outputs.tf              # Outputs do Terraform
├── kubeconfig              # Kubeconfig gerado (após apply)
└── cloud-init/
    ├── server.yaml.tpl     # Template para servidor inicial
    ├── join.yaml.tpl       # Template para CPs adicionais
    └── worker.yaml.tpl     # Template para workers
```

## 🔧 Variáveis Importantes

| Variável | Descrição | Exemplo | Obrigatório |
|----------|-----------|---------|-------------|
| `tenancy_ocid` | OCID do Tenancy OCI | `ocid1.tenancy.oc1..aaa...` | ✅ |
| `user_ocid` | OCID do usuário OCI | `ocid1.user.oc1..aaa...` | ✅ |
| `fingerprint` | Fingerprint da chave API | `aa:bb:cc:dd:ee:ff...` | ✅ |
| `private_key_path` | Caminho da chave privada OCI | `~/.oci/oci_api_key.pem` | ✅ |
| `region` | Região OCI | `sa-saopaulo-1` | ✅ |
| `compartment_id` | OCID do compartment | `ocid1.compartment.oc1..` | ✅ |
| `route53_zone_id` | ID da zona Route53 | `Z1PA6795UKMFR9` | ✅ |
| `domain` | Domínio principal | `example.com` | ✅ |
| `k3s_api_dns` | Subdomínio K3s API | `k3s` | ✅ |
| `public_ip` | Seu IP para SSH | `203.0.113.0/32` | ⚠️ |
| `aws_access_key_id` | Chave AWS | `AKIA...` | ✅ |
| `aws_secret_access_key` | Secret AWS | `wJalr...` | ✅ |

## 🌐 Provedores DNS Alternativos

### Cloudflare
```hcl
# Substitua route53.tf por:
resource "cloudflare_record" "k3s" {
  zone_id = var.cloudflare_zone_id
  name    = var.k3s_api_dns
  value   = oci_load_balancer_load_balancer.k3s_lb.ip_address_details[0].ip_address
  type    = "A"
  ttl     = 60
}
```

### Google Cloud DNS
```hcl
# Substitua route53.tf por:
resource "google_dns_record_set" "k3s" {
  name = "${var.k3s_api_dns}.${var.domain}."
  type = "A"
  ttl  = 60
  managed_zone = var.google_dns_zone
  rrdatas = [oci_load_balancer_load_balancer.k3s_lb.ip_address_details[0].ip_address]
}
```

### DNS Manual
Se preferir configurar DNS manualmente, comente o `route53.tf` e configure:
```
k3s.example.com -> <load_balancer_ip>
```

## 🔍 Troubleshooting

### Problema: Node não ingressa no cluster
```bash
# Verificar logs
ssh opc@<node-ip> "sudo journalctl -u k3s -f"

# Verificar conectividade
ssh opc@<node-ip> "nc -zv <master-ip> 6443"

# Verificar firewall
ssh opc@<node-ip> "sudo firewall-cmd --list-ports"
```

### Problema: DNS não resolve
```bash
# Testar resolução
nslookup k3s.example.com

# Verificar Route53
aws route53 list-resource-record-sets --hosted-zone-id <zone-id>
```

### Problema: Certificados SSL
```bash
# Verificar certificados
kubectl get certificates -A

# Ver eventos
kubectl describe certificate <cert-name>
```

## 🧹 Limpeza

Para destruir toda a infraestrutura:
```bash
terraform destroy
```

**⚠️ Atenção:** Isso removerá **todos os recursos** criados e **dados do cluster**.

## 💰 Custos

### Oracle Cloud (OCI) - Pay-as-you-go
- **VMs ARM (A1.Flex)**: **GRATUITO** (Always Free)
- **Load Balancer**: **GRATUITO** (10 Mbps flexível)
- **VCN/Subnets**: **GRATUITO**
- **Egress**: Primeiros 10TB gratuitos

### Amazon AWS
- **Route53 Hosted Zone**: $0.50/mês
- **DNS Queries**: $0.40 por milhão

**💡 Todos os recursos OCI são gratuitos!** Custos apenas no DNS do AWS Route53.

## 🔐 Segurança

### Boas Práticas Implementadas
- ✅ Network Security Groups restritivos
- ✅ Firewall local configurado
- ✅ Acesso SSH limitado por IP
- ✅ Certificados TLS automáticos
- ✅ RBAC nativo do K3s
- ✅ Etcd criptografado em trânsito

### Próximos Passos de Segurança
- [ ] Implementar Falco para runtime security
- [ ] Configurar Gatekeeper/OPA
- [ ] Habilitar audit logs
- [ ] Implementar Vault para secrets

## 📚 Referências

- [K3s Documentation](https://docs.k3s.io/)
- [Oracle Cloud Infrastructure](https://docs.oracle.com/en-us/iaas/)
- [Terraform OCI Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs)
- [AWS Route53](https://docs.aws.amazon.com/route53/)

## 🤝 Contribuição

1. Fork o projeto
2. Crie uma feature branch
3. Commit suas mudanças  
4. Abra um Pull Request

## 📄 Licença

MIT License - veja `LICENSE` para detalhes.

---
