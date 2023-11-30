output "node-sg-id" {
  value = module.eks.node_security_group_id
}
output "node-group-sg-id" {
    value = module.eks.eks_managed_node_groups.NODE_GROUP01.security_group_id
}