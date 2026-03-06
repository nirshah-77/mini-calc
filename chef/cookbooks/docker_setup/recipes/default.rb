%w[ca-certificates curl gnupg lsb-release apt-transport-https].each do |pkg|
  package pkg
end

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

execute 'add_docker_apt_repo' do
  command <<~BASH
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  BASH
  creates '/etc/apt/sources.list.d/docker.list'
end

execute 'apt_update_after_docker_repo' do
  command 'apt-get update'
  action :run
end

%w[docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin].each do |pkg|
  package pkg
end

service 'docker' do
  action [:enable, :start]
end

execute 'pull_calc_image' do
  command 'docker pull nirshah77/mini-calc:latest'
end

execute 'run_calc_container' do
  command 'docker run -d -i --name mini-calc -p 8080:8080 --restart unless-stopped nirshah77/mini-calc:latest'
  not_if 'docker ps -a --format "{{.Names}}" | grep -q "^mini-calc$"'
end
