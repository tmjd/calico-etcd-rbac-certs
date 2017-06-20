# Size of the cluster created by Vagrant
num_instances=2

# Change basename of the VM
instance_name_prefix="k8s-node"

# Official CoreOS channel from which updates should be downloaded
update_channel='stable'

Vagrant.configure("2") do |config|
  # always use Vagrants insecure key
  config.ssh.insert_key = false

  config.vm.box = "coreos-%s" % update_channel
  config.vm.box_version = ">= 1122.0.0"
  config.vm.box_url = "http://%s.release.core-os.net/amd64-usr/current/coreos_production_vagrant.json" % update_channel

  config.vm.provider :virtualbox do |v|
    # On VirtualBox, we don't have guest additions or a functional vboxsf
    # in CoreOS, so tell Vagrant that so it can be smarter.
    v.check_guest_additions = false
    v.memory = 1024 
    v.cpus = 1
    v.functional_vboxsf     = false
  end

  # To speed up multiple runs of 'vagrant up' or when experiencing failures
  # of the systemd service 'user-data', the Kubernetes binaries can be
  # pre-downloaded.  To download the binaries, downloaded the script
  # http://0.0.0.0:4000/master/getting-started/kubernetes/installation/vagrant/fetch_k8s_binaries.sh
  # into the same directory as this Vagrantfile, make it executable with
  # `chmod +x fetch_k8s_binaries.sh`, and then run it to create a k8s directory
  # and download the needed k8s binaries.
  #
  # If the environment variable K8S_CACHED is set to true and if the directory
  # exists in the same folder as this Vagrantfile it will be mounted into
  # each VM.  (This requires nfsd in Linux and may prompt for superuser
  # permissions. This has only been tested on linux.)
  if ENV['K8S_CACHED'] == "true"
    if File.directory?(File.expand_path("./k8s"))
      config.vm.synced_folder "./k8s", "/k8s", id: "core", :nfs => true,  :mount_options   => ['nolock,vers=3,udp,ro']
    end
  end

  $fetch_k8s= <<SCRIPT
#!/bin/bash
k8s_ver="v1.7.0-beta.1"

if [ $# -eq 0 ]; then
    binaries="kubectl kube-apiserver kube-controller-manager kubelet kube-proxy kube-scheduler"
else
    binaries="$@"
fi

mkdir -p k8s

for x in $binaries; do
  ver_binary=${x}-$k8s_ver
  if [ ! -f k8s/${ver_binary}.downloaded ]; then
    /usr/bin/wget -O k8s/${ver_binary} https://storage.googleapis.com/kubernetes-release/release/$k8s_ver/bin/linux/amd64/$x
    if [ $? -eq 0 ]; then
      touch k8s/${ver_binary}.downloaded
    fi
  else
    echo "$x ($k8s_ver) already downloaded"
  fi
done

SCRIPT
  $init_k8s= <<SCRIPT
#!/bin/bash
k8s_ver="v1.7.0-beta.1"

if [ ! -d /k8s ]; then
  mkdir /k8s
  # fetch_k8s_binaries.sh downloads to a subdirectory k8s so cd to the the
  # parent directory
  cd /
  /opt/k8s/setup/fetch_k8s_binaries.sh $@
fi

mkdir -p /opt/bin

for x in $@; do
  binary=$x
  ver_binary=${binary}-$k8s_ver
  if [ ! -f /k8s/${ver_binary}.downloaded ]; then
    echo "ERROR: $binary version $k8s_ver was not downloaded"
    exit 1
  fi
  cp /k8s/${ver_binary} /opt/bin/$binary
  /usr/bin/chmod +x /opt/bin/$binary
done

SCRIPT

  # Set up each box
  (1..num_instances).each do |i|
    if i == 1
      vm_name = "k8s-master"
    else
      vm_name = "%s-%02d" % [instance_name_prefix, i-1]
    end

    config.vm.define vm_name do |host|
      host.vm.hostname = vm_name

      ip = "172.18.18.#{i+100}"
      host.vm.network :private_network, ip: ip
      # Workaround VirtualBox issue where eth1 has 2 IP Addresses at startup
      host.vm.provision :shell, :inline => "sudo /usr/bin/ip addr flush dev eth1"
      host.vm.provision :shell, :inline => "sudo /usr/bin/ip addr add #{ip}/24 dev eth1"

      host.vm.provision :shell, :inline => "sudo mkdir -p /opt/k8s/setup"
      host.vm.provision :shell, :inline => "echo '#{$fetch_k8s}' > /opt/k8s/setup/fetch_k8s_binaries.sh"
      host.vm.provision :shell, :inline => "echo '#{$init_k8s}' > /opt/k8s/setup/k8s_binary_init.sh"
      host.vm.provision :shell, :inline => "sudo chmod +x /opt/k8s/setup/*"

      host.vm.provision :shell, :inline => "sudo mkdir -p /etc/etcd"
      host.vm.provision :shell, :inline => "sudo mkdir -p /tmp/certs; sudo chmod -R 777 /tmp/certs"

      # Get K8s certs ready for access to etcd
      host.vm.provision :file, :source => "tls-setup/certs/kubernetes-key.pem", :destination => "/tmp/certs/kubernetes.key"
      host.vm.provision :file, :source => "tls-setup/certs/kubernetes.pem", :destination => "/tmp/certs/kubernetes.crt"

      if i == 1
        # Configure the master.
        host.vm.provision :file, :source => "tls-setup/certs/ca.pem", :destination => "/tmp/certs/ca.crt"
        host.vm.provision :file, :source => "tls-setup/certs/etcd#{i}-key.pem", :destination => "/tmp/certs/etcd-member.key"
        host.vm.provision :file, :source => "tls-setup/certs/etcd#{i}.pem", :destination => "/tmp/certs/etcd-member.crt"

        host.vm.provision :shell, :inline => "sudo mv /tmp/certs/* /etc/etcd"
        host.vm.provision :shell, :inline => "sudo chown root /etc/etcd/*; sudo chmod 777 /etc/etcd/*"

        host.vm.provision :file, :source => "master-config.yaml", :destination => "/tmp/vagrantfile-user-data"
        host.vm.provision :shell, :inline => "sed -i -e 's|__ID__|#{i}|g' /tmp/vagrantfile-user-data"
        host.vm.provision :shell, :inline => "mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true

        host.vm.provision :shell, :inline => "echo '127.0.0.1\tlocalhost' > /etc/hosts", :privileged => true
        host.vm.provision :shell, :inline => "mkdir -p /etc/kubernetes/manifests/", :privileged => true
      else
        # Configure a node.
        host.vm.provision :file, :source => "tls-setup/certs/ca.pem", :destination => "/tmp/certs/ca.crt"
        host.vm.provision :file, :source => "tls-setup/certs/proxy1-key.pem", :destination => "/tmp/certs/etcd-proxy.key"
        host.vm.provision :file, :source => "tls-setup/certs/proxy1.pem", :destination => "/tmp/certs/etcd-proxy.crt"
        host.vm.provision :shell, :inline => "sudo mv /tmp/certs/* /etc/etcd"
        host.vm.provision :shell, :inline => "sudo chown root /etc/etcd/*; sudo chmod 777 /etc/etcd/*"

        host.vm.provision :file, :source => "node-config.yaml", :destination => "/tmp/vagrantfile-user-data"
        host.vm.provision :shell, :inline => "mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true
      end
    end
  end
end
