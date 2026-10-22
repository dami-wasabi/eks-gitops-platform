output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "configure_kubectl" {
  description = "Run this to point kubectl at the new cluster."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "argocd_ui" {
  description = "Open the Argo CD UI on http://localhost:8081 (user: admin)."
  value       = "kubectl -n argocd port-forward svc/argocd-server 8081:80"
}

output "app_url" {
  description = "Prints the public NLB address of the gateway once Argo CD has synced it."
  value       = "kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=public -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'"
}
