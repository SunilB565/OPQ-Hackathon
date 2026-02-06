output "cluster_id" {
  value = aws_ecs_cluster.this.id
}

output "order_service" {
  value = aws_ecs_service.order.id
}

output "storage_service" {
  value = aws_ecs_service.storage.id
}
