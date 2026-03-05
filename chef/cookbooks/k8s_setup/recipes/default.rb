#
# Cookbook:: k8s_setup
# Recipe:: default
#
# Uses Chef to:
#   1. Install Docker CE on the EC2 instance
#   2. Pull the application image from Docker Hub
#   3. Run the container
#

# ── 1. Install Docker CE packages ─────────────────────────────────
%w[docker-ce docker-ce-cli containerd.io].each do |pkg|
  package pkg
end

# ── 2. Enable and start Docker service ────────────────────────────
service 'docker' do
  action [:enable, :start]
end

# ── 3. Pull the application image from Docker Hub ─────────────────
execute 'pull_sqrt_image' do
  command 'docker pull nirshah77/sqrt-app:latest'
end

# ── 4. Run the container ──────────────────────────────────────────
# --restart unless-stopped  : auto-restart on EC2 reboot
# not_if guard              : idempotent — won't create duplicate containers
execute 'run_sqrt_container' do
  command 'docker run -d --name sqrt-app --restart unless-stopped nirshah77/sqrt-app:latest'
  not_if 'docker ps -a --format "{{.Names}}" | grep -q "^sqrt-app$"'
end
