# kubernetes-in-production

A production-like Amazon EKS reference cluster built with Terraform.

## What gets built

| Layer | Details |
|---|---|
| Network | A new VPC `10.0.0.0/16` across eu-west-1a/b/c. It has three private `/20` subnets for nodes and pods, three public `/24` subnets for NAT and internet-facing load balancers, and **one NAT gateway per AZ**. Subnets carry the tags the LB Controller uses to discover them. |
| Control plane | EKS `1.36`, named `eks-dev`. The Kubernetes API endpoint is **private-only**, reachable through VPC-connected administration paths. Secrets are encrypted with a KMS key. `api`, `audit` and `authenticator` logs go to CloudWatch with 30-day retention. |
| Access | Access entries only (`authentication_mode = API`). Terraform creates a dedicated IAM role, `eks-dev-admin`, with `AmazonEKSClusterAdminPolicy`. You and the platform stack assume it. The identity that runs Terraform gets no Kubernetes access of its own. |
| Laptop access | An AWS Client VPN endpoint (`enable_client_vpn`). It uses mutual TLS with a CA, server and client certificate that Terraform generates. It is split-tunnel, so only VPC traffic goes through it, and it uses the VPC DNS resolver. It is associated with one private subnet. Its security group can reach only the Kubernetes API on 443, and connections are logged to CloudWatch. |
| Nodes | One managed node group, `default`: `m6i.large` on-demand, AL2023, min 3 / desired 3 / max 6, spread across 3 AZs. Each node has a 50 GiB encrypted gp3 root volume, IMDSv2 enforced (hop limit 1), and SSM Session Manager access, so there's no SSH. |
| Add-ons (EKS managed) | `vpc-cni`, `kube-proxy`, `coredns`, `eks-pod-identity-agent`, `aws-ebs-csi-driver` (authenticated through Pod Identity), and `metrics-server`; all versions are explicit inputs |
| Platform (in-cluster) | A default `gp3` StorageClass (encrypted, `WaitForFirstConsumer`) and the AWS Load Balancer Controller Helm chart `3.6.0`, which authenticates through Pod Identity. |
| State | An S3 bucket (`eks-tfstate-<ACCOUNT_ID>-eu-west-1`) that is versioned, encrypted with a rotation-enabled customer-managed KMS key, TLS-only, and uses S3-native locking (`use_lockfile`), so no DynamoDB is needed. |

Workload IAM uses **EKS Pod Identity** rather than IRSA, so no OIDC provider is created.

## Layout

```
backend.hcl.example     Template for the gitignored backend.hcl (state bucket and KMS alias)
bootstrap/              S3 bucket for Terraform state (local state, apply once)
modules/
  eks-infra/            VPC + EKS + node group + add-ons + Pod Identity roles + Client VPN
  eks-platform/         In-cluster resources: gp3 StorageClass, AWS LB Controller
envs/dev/
  infra/                Root stack -> modules/eks-infra       (state: envs/dev/infra/terraform.tfstate)
  platform/             Root stack -> modules/eks-platform    (state: envs/dev/platform/terraform.tfstate)
                        Reads infra outputs via terraform_remote_state
```

`infra` and `platform` are separate stacks. The helm and kubernetes providers need a cluster that already exists, so keeping them out of the stack that creates the cluster avoids a chicken-and-egg problem and makes destroy reliable.

## Prerequisites

| Tool | Version |
|---|---|
| Terraform | `>= 1.10` |
| AWS CLI v2 | Used by `aws eks get-token` |
| kubectl | **1.35–1.37**. kubectl only supports a skew of ±1 minor version from the server. |
| [AWS VPN Client](https://aws.amazon.com/vpn/client-vpn-download/) | Or any OpenVPN-compatible client. Imports the generated `.ovpn` profile. |

## Local configuration

Account-specific values are kept out of git. Copy each template and fill it in. The root `.gitignore` protects backend configuration, local auto-vars, Terraform state, plan files, and the `.terraform/` cache:

| File (gitignored) | Template | Contains |
|---|---|---|
| `backend.hcl` | [backend.hcl.example](backend.hcl.example) | The state bucket name and KMS alias, shared by every stack's `init` |
| `bootstrap/local.auto.tfvars` | [example](bootstrap/local.auto.tfvars.example) | The state bucket name to create |
| `envs/dev/infra/local.auto.tfvars` | [example](envs/dev/infra/local.auto.tfvars.example) | required `admin_trusted_principal_arns` and reviewed `addon_versions` |
| `envs/dev/platform/local.auto.tfvars` | [example](envs/dev/platform/local.auto.tfvars.example) | The state bucket name, used to read the infra stack's outputs |

Terraform loads `*.auto.tfvars` files automatically.

## Deploy

```sh
# 1. State bucket (once per account)
terraform -chdir=bootstrap init
terraform -chdir=bootstrap plan -out=/tmp/bootstrap.tfplan
terraform -chdir=bootstrap apply /tmp/bootstrap.tfplan

# 2. Network + cluster + nodes + add-ons (~15–20 min)
terraform -chdir=envs/dev/infra init -reconfigure -backend-config=../../../backend.hcl
terraform -chdir=envs/dev/infra plan -out=/tmp/infra.tfplan
terraform -chdir=envs/dev/infra apply /tmp/infra.tfplan

# 3. Connect the laptop: export the VPN profile, import it into AWS VPN Client and connect
#    (see "Laptop VPN access"), then create a kubeconfig that assumes the eks-dev-admin role
(umask 077 && terraform -chdir=envs/dev/infra output -raw client_vpn_config > ~/eks-dev.ovpn)
$(terraform -chdir=envs/dev/infra output -raw configure_kubectl)
kubectl get nodes

# 4. In-cluster platform components
terraform -chdir=envs/dev/platform init -reconfigure -backend-config=../../../backend.hcl
terraform -chdir=envs/dev/platform plan -out=/tmp/platform.tfplan
terraform -chdir=envs/dev/platform apply /tmp/platform.tfplan
```

Review each plan artifact before applying it. Do not use `-auto-approve` for production or shared environments.

The bootstrap stack creates the `alias/terraform-state` customer-managed KMS key. The IAM principal running the other stacks must have `kms:Encrypt`, `kms:Decrypt`, `kms:GenerateDataKey`, and `kms:DescribeKey` on that key. Existing state objects are not re-encrypted automatically; verify or migrate them after the backend is reconfigured.

The Kubernetes API is private-only. Run `kubectl` and the platform stack while connected to the Client VPN, or from a Direct Connect- or VPC-connected host; without one of these the endpoint is unreachable.

Optionally, after step 1 you can move the bootstrap stack's own state into the bucket. Add a `backend "s3"` block with `key = "bootstrap/terraform.tfstate"` and `region = "eu-west-1"` to [bootstrap/versions.tf](bootstrap/versions.tf), then run `terraform -chdir=bootstrap init -migrate-state -backend-config=../backend.hcl`. The bucket name comes from `backend.hcl`.

Access to the cluster goes through the `eks-dev-admin` role. Set `admin_trusted_principal_arns` in `envs/dev/infra/local.auto.tfvars` to explicit IAM role or user ARNs; an account-wide trust fallback is not permitted.

## Laptop VPN access

The infra stack creates an AWS Client VPN endpoint when `enable_client_vpn = true` (the default in [envs/dev/infra/terraform.tfvars](envs/dev/infra/terraform.tfvars)). The VPN only provides network reach to the API endpoint. `kubectl` still authenticates by assuming `eks-dev-admin`.

1. Export the profile. It contains the client private key, so keep it out of git and readable only by you:
   ```sh
   (umask 077 && terraform -chdir=envs/dev/infra output -raw client_vpn_config > ~/eks-dev.ovpn)
   ```
2. In AWS VPN Client, choose **File → Manage Profiles → Add Profile**, select `~/eks-dev.ovpn`, then connect.
3. Check that the endpoint resolves to VPC addresses (`10.0.x.x`), then run `kubectl get nodes`:
   ```sh
   dig +short "$(terraform -chdir=envs/dev/infra output -raw cluster_endpoint | sed 's|https://||')"
   ```

Only traffic to `10.0.0.0/16` goes through the tunnel. Clients get addresses from `client_vpn_cidr` (`10.200.0.0/22`). If that range overlaps your home or office network, change it.

Certificates: the CA, server and client keys are generated by Terraform and stored in the KMS-encrypted state. The server and client certificates are valid for 2 years. Any apply within 30 days of expiry re-issues them. After that, export the profile again and re-import it. There is no revocation list. To cut off a leaked profile, disable and re-enable the VPN. That creates a new CA and invalidates every existing profile.

## Smoke tests

```sh
# 3 Ready nodes, one per AZ
kubectl get nodes -L topology.kubernetes.io/zone,role

# metrics-server
kubectl top nodes

# All add-ons and the LB controller healthy
kubectl -n kube-system get pods

# gp3 StorageClass is the default and provisions volumes
kubectl get storageclass
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: smoke-pvc }
spec:
  accessModes: [ReadWriteOnce]
  resources: { requests: { storage: 1Gi } }
---
apiVersion: v1
kind: Pod
metadata: { name: smoke-pvc }
spec:
  containers:
    - name: app
      image: public.ecr.aws/docker/library/busybox:stable
      command: [sh, -c, "echo ok > /data/ok && sleep 3600"]
      volumeMounts: [{ name: data, mountPath: /data }]
  volumes: [{ name: data, persistentVolumeClaim: { claimName: smoke-pvc } }]
EOF
kubectl get pvc smoke-pvc        # STATUS should become Bound

# LB controller provisions an internet-facing ALB
kubectl create deployment smoke-web --image=public.ecr.aws/nginx/nginx:stable --port=80
kubectl expose deployment smoke-web --port=80
kubectl create ingress smoke-web --class=alb --rule="/*=smoke-web:80" \
  --annotation alb.ingress.kubernetes.io/scheme=internet-facing \
  --annotation alb.ingress.kubernetes.io/target-type=ip
kubectl get ingress smoke-web -w # ADDRESS gets an ALB hostname within ~2 min

# Clean up (deletes the ALB and the EBS volume)
kubectl delete ingress,service,deployment smoke-web
kubectl delete pod,pvc smoke-pvc
```

## Day-2 operations

- **kubectl times out:** check that AWS VPN Client shows *Connected* and that the endpoint hostname resolves to `10.0.x.x` (see [Laptop VPN access](#laptop-vpn-access)). Connection attempts and failures are logged in the `/aws/clientvpn/eks-dev` CloudWatch log group.
- **VPN cost:** the endpoint is billed per subnet association hour, whether or not anyone is connected. Set `enable_client_vpn = false` and apply `infra` to remove it. Enabling it again creates new certificates, so export the profile again.
- **Scaling nodes:** there is no Cluster Autoscaler. After creation the EKS module ignores `desired_size`, so either raise `node_min_size` (and `node_max_size` if needed) and apply, or change the size directly:
  ```sh
  aws eks list-nodegroups --cluster-name eks-dev
  aws eks update-nodegroup-config --cluster-name eks-dev --nodegroup-name <name> --scaling-config minSize=3,maxSize=6,desiredSize=4
  ```
- **Node shell:** `aws ssm start-session --target <instance-id>`
- **Kubernetes upgrade:** bump `kubernetes_version` one minor version at a time, select and review compatible add-on versions for the target region, update `addon_versions`, and apply `infra`.
- **Adding an environment:** copy `envs/dev` to `envs/prod`, then change the backend `key`s, `infra_state_key`, and the tfvars (name, CIDR, sizes, and `deletion_protection = true`). Remember to create the gitignored `local.auto.tfvars` files there too.

## Destroy

First delete any `Ingress` objects, `LoadBalancer` Services and PVCs. Their ALBs, NLBs and EBS volumes were created by controllers, not by Terraform, so Terraform won't remove them and they would be orphaned.

```sh
terraform -chdir=envs/dev/platform destroy
terraform -chdir=envs/dev/infra destroy
```

The state bucket has `prevent_destroy` set and is kept deliberately.

## Estimated cost (eu-west-1, on-demand, before data transfer)

| Item | ~USD / month |
|---|---|
| EKS control plane | 73 |
| 3 × m6i.large | 235 |
| 3 × NAT gateway, plus $/GB processed | 105 |
| EBS (3 × 50 GiB gp3) | 13 |
| Client VPN: 1 subnet association, plus ~$0.05 per connected hour | 73 |
| KMS key, CloudWatch logs | a few |
| **Total** | **~505** |
