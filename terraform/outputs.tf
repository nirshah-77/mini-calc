output "server_public_ip" {
  description = "Public IP of the app server EC2 instance"
  value       = aws_instance.app_server.public_ip
}