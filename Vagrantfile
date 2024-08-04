Vagrant.configure(2) do |config|

    etcHosts = ""
	ingressNginx = ""
	wordpress = ""
	wordpressUrl = "wordpress.kub"
	
    # Check ingress controller
	case ARGV[0]
    when "provision", "up"

    print "Do you want nginx as ingress controller (y/n) ?\n"
    ingressNginx = STDIN.gets.chomp
    print "\n"
        if ingressNginx == "y"
            print "Do you want a wordpress in your kubernetes cluster (y/n) ?\n"
            wordpress = STDIN.gets.chomp
            print "\n"
            if wordpress == "y"
                print "Which url for your wordpress ?"
                wordpressUrl = STDIN.gets.chomp
                unless wordpressUrl.empty? then wordpressUrl else 'wordpress.kube' end
            end
         end
    else
    # do nothing
    end
    common = <<-SHELL
    sudo apt update -qq 2>&1 >/dev/null
    sudo apt install -y -qq git vim tree net-tools telnet git python3-pip sshpass nfs-common 2>&1 >/dev/null
    #curl -fsSL https://get.docker.com -o get-docker.sh 2>&1
    #sudo sh get-docker.sh 2>&1 >/dev/null
    sudo apt install -y docker.io
    docker --version
    sudo systemctl enable docker
    sudo usermod -aG docker vagrant
    sudo service docker start
    sudo systemctl start docker
    sudo systemctl status docker
    sudo echo "autocmd filetype yaml setlocal ai ts=2 sw=2 et" > /home/vagrant/.vimrc
    sudo sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
    sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
    sudo systemctl restart sshd
    sudo -u vagrant chmod 600 /home/vagrant/.ssh/authorized_keys
    #echo "ChallengeResponseAuthentication yes" | sudo tee -a /etc/ssh/sshd_config
    # sudo sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
    # sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
    # sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    # sudo sed -i 's/#AuthorizedKeysFile\s\+.*$/AuthorizedKeysFile \.ssh\/authorized_keys \.ssh\/authorized_keys2/' /etc/ssh/sshd_config
    #sudo sed -i 's/#KbdInteractiveAuthentication yes/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config   
    SHELL
  
    # set servers list and their parameters
    NODES = [
    { :hostname => "autohaprox", :ip => "192.168.56.20", :cpus => 1, :mem => 512, :type => "haproxy" },
    { :hostname => "autokmaster", :ip => "192.168.56.21", :cpus => 2, :mem => 2024, :type => "kub" },
    { :hostname => "autoknode", :ip => "192.168.56.22", :cpus => 2, :mem => 2024, :type => "kub" },
    { :hostname => "autodep", :ip => "192.168.56.30", :cpus => 1, :mem => 512, :type => "deploy" }
    ]
    # define /etc/hosts for all servers
    NODES.each do |node|
        if node[:type] != "haproxy"
            etcHosts += "echo '" + node[:ip] + "   " + node[:hostname] + "' >> /etc/hosts" + "\n"
        else
            etcHosts += "echo '" + node[:ip] + "   " + node[:hostname] + " autoelb.kub ' >> /etc/hosts" + "\n"
        end
    end #end NODES
    
    config.vm.box = "ubuntu/jammy64"
    config.vm.box_url = "ubuntu/jammy64"
  
    # run installation
    NODES.each do |node|
        config.vm.define node[:hostname] do |cfg|
            cfg.vm.hostname = node[:hostname]
            cfg.vm.network "private_network", ip: node[:ip]
            cfg.vm.provider "virtualbox" do |v|
                v.customize [ "modifyvm", :id, "--cpus", node[:cpus] ]
                v.customize [ "modifyvm", :id, "--memory", node[:mem] ]
                v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
                v.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
                v.customize ["modifyvm", :id, "--name", node[:hostname] ]
                #v.customize [ "modifyvm", :id, "--ioapic", "on" ]
                #v.customize [ "modifyvm", :id, "--nictype1", "virtio" ]
        
          end #end provider
                    
          #for all
            cfg.vm.provision :shell, :inline => etcHosts
          #for haproxy
            if node[:type] == "haproxy"
                cfg.vm.provision :shell, :path => "install_haproxy.sh"
            end
          # for all servers in cluster (need docker)
            if node[:type] == "kub"
                cfg.vm.provision :shell, :inline => common
            end
          # for the deploy server
            if node[:type] == "deploy"
                cfg.vm.provision :shell, :inline => common
                cfg.vm.provision :shell, :path => "install_kubespray.sh", :args => ingressNginx
                if wordpress == "y"
                    cfg.vm.provision :shell, :path => "install_nfs.sh"
                    cfg.vm.provision :shell, :path => "install_wordpress.sh", :args => wordpressUrl
                end
            end

        end # end config
    end # end nodes
end 
  