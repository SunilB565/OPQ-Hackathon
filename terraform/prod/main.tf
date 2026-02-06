provider "aws" {
  region = var.region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_ecr_repository" "order" {
  name = "order-service"
}

resource "aws_ecr_repository" "storage" {
  name = "storage-service"
}

resource "aws_ecs_cluster" "this" {
  name = "hackathon-cluster-prod"
}

resource "aws_service_discovery_private_dns_namespace" "ns" {
  name = "hackathon.local"
  vpc  = data.aws_vpc.default.id
}

resource "aws_service_discovery_service" "order_sd" {
  name = "order-service"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.ns.id
    dns_records {
      ttl  = 60
      type = "A"
    }
  }
}

resource "aws_service_discovery_service" "storage_sd" {
  name = "storage-service"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.ns.id
    dns_records {
      ttl  = 60
      type = "A"
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole-hackathon-prod"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_exec_attach" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "order" {
  name = "/ecs/order-service-prod"
}

resource "aws_cloudwatch_log_group" "storage" {
  name = "/ecs/storage-service-prod"
}

resource "aws_ecs_task_definition" "order" {
  family                   = "order-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name = "order-service"
      image = var.order_image
      essential = true
      portMappings = [{ containerPort = 3000, protocol = "tcp" }]
      environment = [{ name = "STORAGE_URL", value = "http://storage-service.hackathon.local:4000" }]
      logConfiguration = { logDriver = "awslogs", options = { "awslogs-group" = aws_cloudwatch_log_group.order.name, "awslogs-region" = var.region, "awslogs-stream-prefix" = "order" } }
    }
  ])
}

resource "aws_ecs_task_definition" "storage" {
  family                   = "storage-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name = "storage-service"
      image = var.storage_image
      essential = true
      portMappings = [{ containerPort = 4000, protocol = "tcp" }]
      environment = [{ name = "ADMIN_TOKEN", value = var.admin_token }]
      logConfiguration = { logDriver = "awslogs", options = { "awslogs-group" = aws_cloudwatch_log_group.storage.name, "awslogs-region" = var.region, "awslogs-stream-prefix" = "storage" } }
    }
  ])
}

resource "aws_ecs_service" "storage" {
  name            = "storage-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.storage.arn
  desired_count   = 2

  launch_type = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.private[*].id
    assign_public_ip = false
    security_groups = [aws_security_group.ecs_tasks.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.storage.arn
    container_name   = "storage-service"
    container_port   = 4000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.storage_sd.arn
  }
}

resource "aws_ecs_service" "order" {
  name            = "order-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.order.arn
  desired_count   = 2
  launch_type = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.private[*].id
    assign_public_ip = false
    security_groups = [aws_security_group.ecs_tasks.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.order.arn
    container_name   = "order-service"
    container_port   = 3000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.order_sd.arn
  }
}

# Prometheus
resource "aws_cloudwatch_log_group" "prometheus" {
  name = "/ecs/prometheus-prod"
}

resource "aws_ecs_task_definition" "prometheus" {
  family                   = "prometheus"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name = "prometheus"
      image = "prom/prometheus:latest"
      essential = true
      portMappings = [{ containerPort = 9090, protocol = "tcp" }]
      logConfiguration = { logDriver = "awslogs", options = { "awslogs-group" = aws_cloudwatch_log_group.prometheus.name, "awslogs-region" = var.region, "awslogs-stream-prefix" = "prom" } }
    }
  ])
}

resource "aws_ecs_service" "prometheus" {
  name            = "prometheus"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type = "FARGATE"
  network_configuration {
    subnets         = data.aws_subnet_ids.default.ids
    assign_public_ip = true
    security_groups = []
  }
}

# Grafana
resource "aws_cloudwatch_log_group" "grafana" {
  name = "/ecs/grafana-prod"
}

resource "aws_ecs_task_definition" "grafana" {
  family                   = "grafana"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name = "grafana"
      image = "grafana/grafana:9.0.0"
      essential = true
      portMappings = [{ containerPort = 3000, protocol = "tcp" }]
      logConfiguration = { logDriver = "awslogs", options = { "awslogs-group" = aws_cloudwatch_log_group.grafana.name, "awslogs-region" = var.region, "awslogs-stream-prefix" = "grafana" } }
    }
  ])
}

resource "aws_ecs_service" "grafana" {
  name            = "grafana"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type = "FARGATE"
  network_configuration {
    subnets         = data.aws_subnet_ids.default.ids
    assign_public_ip = true
    security_groups = []
  }
}

# Application Load Balancer for observability (prod)
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg-prod"
  description = "Allow HTTP to ALB"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "alb" {
  name               = "hackathon-alb-prod"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "prometheus" {
  name     = "prometheus-tg-prod"
  port     = 9090
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id
  target_type = "ip"
  health_check {
    path = "/metrics"
    matcher = "200"
    interval = 30
  }
}

resource "aws_lb_target_group" "grafana" {
  name     = "grafana-tg-prod"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id
  target_type = "ip"
  health_check {
    path = "/"
    matcher = "200,302"
    interval = 30
  }
}

resource "aws_lb_target_group" "order" {
  name     = "order-tg-prod"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id
  target_type = "ip"
  health_check {
    path = "/health"
    matcher = "200"
    interval = 30
  }
}

resource "aws_lb_target_group" "storage" {
  name     = "storage-tg-prod"
  port     = 4000
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id
  target_type = "ip"
  health_check {
    path = "/health"
    matcher = "200"
    interval = 30
  }
}

resource "aws_lb_listener_rule" "order_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 120
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.order.arn
  }
  condition {
    path_pattern {
      values = ["/api/order*"]
    }
  }
}

resource "aws_lb_listener_rule" "storage_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 130
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.storage.arn
  }
  condition {
    path_pattern {
      values = ["/api/storage*"]
    }
  }
}


resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# Redirect HTTP -> HTTPS for domain_name if provided
resource "aws_lb_listener_rule" "redirect_to_https" {
  count = var.domain_name == "" ? 0 : 1
  listener_arn = aws_lb_listener.http.arn
  priority = 1
  action {
    type = "redirect"
    redirect {
      protocol = "HTTPS"
      port     = "443"
      status_code = "HTTP_301"
    }
  }
  condition {
    host_header {
      values = [var.domain_name]
    }
  }
}

# If domain provided, create Route53 hosted zone (optional) and ACM cert with DNS validation
locals {
  use_existing_zone = var.hosted_zone_id != ""
}

resource "aws_route53_zone" "this" {
  count = var.create_hosted_zone && var.domain_name != "" && !local.use_existing_zone ? 1 : 0
  name  = var.domain_name
}

data "aws_route53_zone" "existing" {
  count = local.use_existing_zone && var.hosted_zone_id == "" && var.domain_name != "" ? 1 : 0
  name  = var.domain_name
}

resource "aws_acm_certificate" "cert" {
  count = var.domain_name == "" ? 0 : 1
  domain_name = var.domain_name
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  count = var.domain_name == "" ? 0 : length(aws_acm_certificate.cert[0].domain_validation_options)
  zone_id = var.hosted_zone_id != "" ? var.hosted_zone_id : (length(aws_route53_zone.this) > 0 ? aws_route53_zone.this[0].zone_id : data.aws_route53_zone.existing[0].zone_id)
  name    = aws_acm_certificate.cert[0].domain_validation_options[count.index].resource_record_name
  type    = aws_acm_certificate.cert[0].domain_validation_options[count.index].resource_record_type
  ttl     = 60
  records = [aws_acm_certificate.cert[0].domain_validation_options[count.index].resource_record_value]
}

resource "aws_acm_certificate_validation" "cert_validation_complete" {
  count = var.domain_name == "" ? 0 : 1
  certificate_arn = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = aws_route53_record.cert_validation.*.fqdn
}

resource "aws_lb_listener" "https" {
  count = var.domain_name == "" ? 0 : 1
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.cert_validation_complete[0].certificate_arn
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "prometheus_rule_https" {
  count = var.domain_name == "" ? 0 : 1
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 100
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus.arn
  }
  condition {
    path_pattern {
      values = ["/prometheus*"]
    }
  }
}

resource "aws_lb_listener_rule" "grafana_rule_https" {
  count = var.domain_name == "" ? 0 : 1
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 110
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
  condition {
    path_pattern {
      values = ["/grafana*"]
    }
  }
}

resource "aws_route53_record" "alb_alias" {
  count = var.domain_name == "" ? 0 : 1
  zone_id = var.hosted_zone_id != "" ? var.hosted_zone_id : (length(aws_route53_zone.this) > 0 ? aws_route53_zone.this[0].zone_id : data.aws_route53_zone.existing[0].zone_id)
  name    = var.domain_name
  type    = "A"
  alias {
    name = aws_lb.alb.dns_name
    zone_id = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}


resource "aws_lb_listener_rule" "prometheus_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus.arn
  }
  condition {
    path_pattern {
      values = ["/prometheus*"]
    }
  }
}

resource "aws_lb_listener_rule" "grafana_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 110
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
  condition {
    path_pattern {
      values = ["/grafana*"]
    }
  }
}

resource "aws_lb_listener_rule" "order_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 120
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.order.arn
  }
  condition {
    path_pattern {
      values = ["/api/order*"]
    }
  }
}

resource "aws_lb_listener_rule" "storage_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 130
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.storage.arn
  }
  condition {
    path_pattern {
      values = ["/api/storage*"]
    }
  }
}

# Allow ALB to reach ECS tasks on service ports
resource "aws_security_group_rule" "allow_alb_to_ecs_3000" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs_tasks.id
  source_security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "allow_alb_to_ecs_9090" {
  type                     = "ingress"
  from_port                = 9090
  to_port                  = 9090
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs_tasks.id
  source_security_group_id = aws_security_group.alb_sg.id
}

# Attach Prometheus and Grafana services to ALB target groups
resource "aws_ecs_service" "prometheus_alb_service" {
  name            = "prometheus-service-alb"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = aws_subnet.private[*].id
    assign_public_ip = false
    security_groups  = [aws_security_group.ecs_tasks.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.prometheus.arn
    container_name   = "prometheus"
    container_port   = 9090
  }
}

resource "aws_ecs_service" "grafana_alb_service" {
  name            = "grafana-service-alb"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = aws_subnet.private[*].id
    assign_public_ip = false
    security_groups  = [aws_security_group.ecs_tasks.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.grafana.arn
    container_name   = "grafana"
    container_port   = 3000
  }
}

output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}
