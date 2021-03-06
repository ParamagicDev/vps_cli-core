# frozen_string_literal: true

module VpsCli
  OMZ_DIR = File.join(Dir.home, '.oh-my-zsh')
  OMZ_PLUGINS = File.join(OMZ_DIR, 'custom', 'plugins')
  # Installes the required packages
  class Install
    # Run the #all_install method, simply a wrapper to catch errors
    #   and check if the user is running linux
    # @see all_install
    def self.full
      unless OS.linux?
        puts 'You are not running on linux. No packages installed.'
        return
      end

      all_install
    end

    # Runs through multiple methods listed below
    # @see #prep
    # @see #packages
    def self.all_install
      prep
      packages
      install_non_apt_packages
    end

    # runs #all_install without the sudo apt-get packages
    # @see #other_tools
    # @see #neovim_support
    # @see #omz_full_install
    # @see Setup#full
    # @see #install_tmux_plugin_manager_and_plugins
    # @see #plug_install_vim_neovim
    # @see #install_gems
    # @see #add_language_servers
    # @see #node_js
    def self.install_non_apt_packages
      # nvm
      # phpenv
      other_tools
      neovim_support
      omz_full_install
      Setup.full
      install_tmux_plugin_manager_and_plugins
      plug_install_vim_neovim
      install_gems
      # node_js
      add_language_servers
      # powerlevel10k
      eslint
    end

    # simply runs apt update, upgrade, and dist-upgrade
    def self.prep
      Rake.sh('sudo apt-get update')
      Rake.sh('sudo apt-get upgrade -y')
      Rake.sh('sudo apt-get dist-upgrade -y')
    end

    # Runs through items found in Packages::UBUNTU
    # @see Packages::UBUNTU
    def self.packages
      pkgs = Packages::UBUNTU.flatten.join(' ').to_s
      Rake.sh("sudo apt-get install -y #{pkgs}")

      begin
      rescue StandardError => e
        VpsCli.errors << e
      end

      puts 'Completed apt-get install on all packages.'
    end

    # installs various other tools and fixes an issue with npm / nodejs
    # installs heroku, ngrok, and adds docker groups
    def self.other_tools
      # add heroku
      Rake.sh('sudo snap install heroku --classic')
      # add tmux plugin manager
      tmp_plugins = File.join(Dir.home, '.tmux', 'plugins', 'tpm')
      unless Dir.exist?(tmp_plugins)
        Rake.mkdir_p(tmp_plugins)
        Rake.sh('git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm')
      end
      # add ngrok
      Rake.sh('sudo npm install --unsafe-perm -g ngrok')
    end

    # installs docker-machine as well as adding docker to sudo group
    def self.docker
      # add docker
      username = Dir.home.split('/')[2]
      begin
        Rake.sh('sudo groupadd docker')
        Rake.sh("sudo usermod -aG docker #{username}")
      rescue RuntimeError
        puts 'docker group already exists.'
        puts 'moving on...'
      end

      docker_machine = "base=https://github.com/docker/machine/releases/download/v0.16.0 && \
  curl -L $base/docker-machine-$(uname -s)-$(uname -m) >/tmp/docker-machine && \
  sudo install /tmp/docker-machine /usr/local/bin/docker-machine"
      begin
        Rake.sh(docker_machine)
      rescue StandardError => e
        VpsCli.errors << e.exception('Unable to install docker-machine')
      end
    end

    # Lots of issues when using npm via apt-get, this seems to fix dependency issues
    # def self.node_js
    #   Rake.sh('curl -sL https://deb.nodesource.com/setup_11.x | sudo -E bash -')
    #   Rake.sh('sudo apt-get install -y nodejs')

    #   Rake.sh('sudo npm install -g npm')
    # end

    # adds neovim support via pip3
    # Also adds neovim via npm for js support
    def self.neovim_support
      Rake.sh('sudo -H pip2 install neovim --system')
      Rake.sh('sudo -H pip3 install neovim --system')
      Rake.sh('pip3 install --user pynvim')
      Rake.sh('pip3 install --user --upgrade pynvim')
      Rake.sh(%(yes "\n" | sudo npm install -g neovim))
    end

    # Runs the following commands, simply a wrapper
    # @see #install_oh_my_zsh
    # @see #install_syntax_highlighting
    # @see #install_autosuggestions
    def self.omz_full_install
      install_oh_my_zsh
      install_syntax_highlighting
      install_autosuggestions
    end

    # Install Oh my zsh
    # @see https://github.com/zsh-users/zsh-autosuggestions
    def self.install_oh_my_zsh
      return if Dir.exist?(OMZ_DIR)

      Rake.sh('git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh')
      Rake.sh(%(sudo usermod --shell /bin/zsh "$USER"))
    end

    def self.install_autosuggestions
      auto = File.join(OMZ_PLUGINS, 'zsh-autosuggestions')
      return if File.exist?(auto)

      Rake.sh("git clone https://github.com/zsh-users/zsh-autosuggestions #{auto}")
    end

    # Install Oh my zsh syntax highlighting
    # @see https://github.com/zsh-users/zsh-syntax-highlighting.git
    def self.install_syntax_highlighting
      syntax = File.join(OMZ_PLUGINS, 'zsh-syntax-highlighting')
      return if File.exist?(syntax)

      Rake.sh("git clone https://github.com/zsh-users/zsh-syntax-highlighting.git #{syntax}")
    end

    # Runs PlugInstall for neovim
    def self.plug_install_vim_neovim
      Rake.sh(%(nvim +'PlugInstall --sync' +qa))
      Rake.sh(%(nvim +'PlugUpdate --sync' +qa))
    end

    # will install tmux plugin manager
    def self.install_tmux_plugin_manager_and_plugins
      install_path = File.join(Dir.home, '.tmux', 'plugins', 'tpm')
      return if File.exist?(install_path)

      Rake.mkdir_p(install_path)
      Rake.sh("git clone https://github.com/tmux-plugins/tpm #{install_path}")
    end

    # Installs all gems located in Packages::GEMS
    # Also will runs 'yard gems' to document all gems via yard
    def self.install_gems
      Packages::GEMS.each { |g| Rake.sh("gem install #{g}") }
      # documents all gems via yard
      Rake.sh('yard gems')
    end

    # Adds the following language servers
    # bash-language-server
    # vscode-html-languageserver-bin
    # vscode-css-languageserver-bin
    # javascript-typescript-langserver
    # does not add solargraph for ruby, installed via gems
    def self.add_language_servers
      npm_install = 'npm install --global'
      # bash
      Rake.sh("#{npm_install} bash-language-server --unsafe-perm")
      # html
      Rake.sh("#{npm_install} vscode-html-languageserver-bin")
      # css
      Rake.sh("#{npm_install} vscode-css-languageserver-bin")
      # js
      Rake.sh("#{npm_install} javascript-typescript-langserver")
      # Dockerfile
      Rake.sh("#{npm_install} dockerfile-language-server-nodejs")
    end

    # def self.powerlevel10k
    #   Rake.sh('git clone https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k')
    # end

    def self.eslint
      Rake.sh('npm install -g eslint')
    end

    # def self.nvm
    #   nvm_path = ENV['NVM_DIR'] || File.join(Dir.home, '.nvm')
    #   Rake.mkdir_p(nvm_path)
    #   Rake.sh('curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash')
    #   # Set the version
    #   # Rake.sh('nvm install 11.15.0')
    #   # Rake.sh('nvm use 11.15.0')
    # end

    # https://github.com/phpenv/phpenv-installer
    # def self.phpenv
    # Rake.sh("curl -L https://raw.githubusercontent.com/phpenv/phpenv-installer/master/bin/phpenv-installer \
    # | bash")
    # Rake.sh('phpenv install --skip-existing 7.3.8')
    # Rake.sh('phpenv global 7.3.8')
    # end
  end
end
