#
# Cookbook:: docker_setup
# Recipe:: default
#
# Uses Chef to:
#   1. Add Docker's official apt repository
#   2. Install Docker CE on the EC2 instance
#   3. Pull the application image from Docker Hub
#   4. Run the container
#

# ── 1. Install prerequisites ───────────────────────────────────────
%w[ca-certificates curl gnupg lsb-release apt-transport-https].each do |pkg|
  package pkg
end

# ── 2. Add Docker's official GPG key ──────────────────────────────
directory '/etc/apt/keyrings' do
  mode '0755'
  action :create
end

execute 'add_docker_gpg_key' do
  command 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg'
  creates '/etc/apt/keyrings/docker.gpg'
end

file '/etc/apt/keyrings/docker.gpg' do
  mode '0644'
end

# ── 3. Add Docker apt repository ──────────────────────────────────
execute 'add_docker_apt_repo' do
  command <<~BASH
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  BASH
  creates '/etc/apt/sources.list.d/docker.list'
end

# ── 4. Update apt cache after adding the new repo ─────────────────
execute 'apt_update_after_docker_repo' do
  command 'apt-get update'
  action :run
end

# ── 5. Install Docker CE packages ─────────────────────────────────
%w[docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin].each do |pkg|
  package pkg
end

# ── 2. Enable and start Docker service ────────────────────────────
service 'docker' do
  action [:enable, :start]
end

# ── 3. Pull the application image from Docker Hub ─────────────────
execute 'pull_calc_image' do
  command 'docker pull nirshah77/mini-calc:latest'
end

# ── 4. Run the container ──────────────────────────────────────────
# -i                        : keep stdin open (needed for docker exec -it ... java calc)
# --restart unless-stopped  : auto-restart on EC2 reboot
# not_if guard              : idempotent — won't create duplicate containers
#
# To test interactively once deployed:
#   docker exec -it mini-calc java calc
execute 'run_calc_container' do
  command 'docker run -d -i --name mini-calc -p 8080:8080 --restart unless-stopped nirshah77/mini-calc:latest'
  not_if 'docker ps -a --format "{{.Names}}" | grep -q "^mini-calc$"'
end

