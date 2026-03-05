#
# Cookbook:: k8s_setup
# Recipe:: default
#
# Installs Docker CE and Kubernetes (kubeadm, kubelet, kubectl) on an Ubuntu EC2 instance.
# On the master node this recipe also initialises the cluster with kubeadm and applies
# a Flannel CNI overlay. Worker nodes are joined separately via the join token.
#

# ──────────────────────────────────────────────
# 1. System prerequisites
# ──────────────────────────────────────────────
%w[apt-transport-https ca-certificates curl gnupg lsb-release].each do |pkg|
  package pkg do
    action :install
  end
end

# Disable swap (Kubernetes requirement)
execute 'disable_swap' do
  command 'swapoff -a && sed -i "/ swap / s/^/#/" /etc/fstab'
  not_if 'swapon --show | grep -q swap'
end

# Load required kernel modules
%w[overlay br_netfilter].each do |mod|
  execute "modprobe_#{mod}" do
    command "modprobe #{mod}"
    not_if "lsmod | grep -q #{mod}"
  end
end

# Persist kernel modules across reboots
file '/etc/modules-load.d/k8s.conf' do
  content "overlay\nbr_netfilter\n"
  mode '0644'
end

# Set sysctl parameters required by Kubernetes networking
file '/etc/sysctl.d/k8s.conf' do
  content <<~EOF
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
  EOF
  mode '0644'
end

execute 'apply_sysctl' do
  command 'sysctl --system'
end

# ──────────────────────────────────────────────
# 2. Install Docker CE
# ──────────────────────────────────────────────
execute 'add_docker_gpg_key' do
  command 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg'
  not_if { ::File.exist?('/usr/share/keyrings/docker-archive-keyring.gpg') }
end

execute 'add_docker_repo' do
  command 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null'
  not_if { ::File.exist?('/etc/apt/sources.list.d/docker.list') }
  notifies :run, 'execute[apt_update_docker]', :immediately
end

execute 'apt_update_docker' do
  command 'apt-get update -y'
  action :nothing
end

%w[docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin].each do |pkg|
  package pkg do
    action :install
  end
end

# Configure containerd to use systemd cgroup driver (required by Kubernetes)
directory '/etc/containerd' do
  action :create
end

execute 'configure_containerd' do
  command 'containerd config default | tee /etc/containerd/config.toml && sed -i "s/SystemdCgroup = false/SystemdCgroup = true/" /etc/containerd/config.toml'
  not_if 'grep -q "SystemdCgroup = true" /etc/containerd/config.toml 2>/dev/null'
  notifies :restart, 'service[containerd]', :immediately
end

service 'containerd' do
  action [:enable, :start]
end

service 'docker' do
  action [:enable, :start]
end

# ──────────────────────────────────────────────
# 3. Install Kubernetes components
# ──────────────────────────────────────────────
execute 'add_k8s_gpg_key' do
  command 'curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg'
  not_if { ::File.exist?('/etc/apt/keyrings/kubernetes-apt-keyring.gpg') }
end

file '/etc/apt/sources.list.d/kubernetes.list' do
  content "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /\n"
  mode '0644'
  notifies :run, 'execute[apt_update_k8s]', :immediately
end

execute 'apt_update_k8s' do
  command 'apt-get update -y'
  action :nothing
end

%w[kubelet kubeadm kubectl].each do |pkg|
  package pkg do
    action :install
  end
end

execute 'hold_k8s_packages' do
  command 'apt-mark hold kubelet kubeadm kubectl'
end

service 'kubelet' do
  action [:enable, :start]
end

# ──────────────────────────────────────────────
# 4. Kubernetes master initialisation
#    (only runs on nodes tagged as 'master')
# ──────────────────────────────────────────────
node_role = node['k8s_setup']['role']   # 'master' or 'worker'

if node_role == 'master'
  execute 'kubeadm_init' do
    command 'kubeadm init --pod-network-cidr=10.244.0.0/16 2>&1 | tee /var/log/kubeadm_init.log'
    not_if { ::File.exist?('/etc/kubernetes/admin.conf') }
  end

  # Set up kubectl for the ubuntu user
  directory '/home/ubuntu/.kube' do
    owner 'ubuntu'
    group 'ubuntu'
    mode '0755'
  end

  execute 'copy_kubeconfig' do
    command 'cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config && chown ubuntu:ubuntu /home/ubuntu/.kube/config'
    not_if { ::File.exist?('/home/ubuntu/.kube/config') }
  end

  # Apply Flannel CNI
  execute 'apply_flannel' do
    command 'kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml --kubeconfig=/home/ubuntu/.kube/config'
    not_if 'kubectl get daemonset -n kube-flannel kube-flannel-ds --kubeconfig=/home/ubuntu/.kube/config 2>/dev/null'
  end

  # Save join command so worker nodes can use it
  execute 'save_join_command' do
    command 'kubeadm token create --print-join-command > /home/ubuntu/join_command.sh && chmod +x /home/ubuntu/join_command.sh'
    not_if { ::File.exist?('/home/ubuntu/join_command.sh') }
  end
end
