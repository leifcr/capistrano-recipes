Capistrano::Configuration.instance.load do
  set :puma_min_threads, 0 unless exists?(:puma_min_threads)
  set :puma_max_threads, 16 unless exists?(:puma_max_threads)

  # The wrapped bin to start puma (bundle exec power...)
  set :puma_bin, 'bundle exec puma' unless exists?(:puma_bin)
  set :puma_control, 'bundle exec pumactl' unless exists?(:puma_control)
  set :puma_socket, ("unix://" + File.join("#{shared_path}","sockets", "puma.sock")) unless exists?(:puma_socket)

  # Defines where the pid will live.
  set(:puma_pid) { File.join(pids_path,"#{app_server}.pid") } unless exists?(:puma_pid)
  set(:puma_state) { File.join(shared_path, "sockets", "puma.state") } unless exists?(:puma_state)
  set(:puma_control_url) { "unix://" + File.join(shared_path, "sockets", "pumactl.sock") } unless exists?(:puma_control_url)

  set :puma_activate_control_app, true unless exists?(:puma_activate_control_app)

  set :puma_on_restart_active, true unless exists?(:puma_on_restart_active)
  # Our puma template to be parsed by erb
  # You may need to generate this file the first time with the generator
  # included in the gem
  set(:puma_local_config) { File.join(templates_path, "puma.rb.erb") } 

  # The remote location of puma's config file. Used by bluepill to fire it up
  set(:puma_remote_config) { File.join(shared_path, "config", "puma.rb") }

  def puma_status_cmd
    "cd #{current_path} && #{puma_control} -S #{puma_state} status"
  end
  
  def puma_stop_cmd
    "cd #{current_path} && #{puma_control} -S #{puma_state} stop"
  end
  
  def puma_restart_cmd
    "cd #{current_path} && #{puma_control} -S #{puma_state} restart"
  end

  def puma_start_cmd
    "cd #{current_path} && #{puma_bin} -C #{puma_remote_config}"
  end

  # Puma 
  #------------------------------------------------------------------------------
  namespace :puma do    
    desc "|capistrano-recipes| Starts puma directly"
    task :start, :roles => :app do
      run puma_start_cmd
    end  
    
    desc "|capistrano-recipes| Stops puma directly"
    task :stop, :roles => :app do
      run puma_stop_cmd
    end  
    
    desc "|capistrano-recipes| Restarts puma directly"
    task :restart, :roles => :app do
      run puma_restart_cmd
    end

    desc "|capistrano-recipes| Flush puma sockets"
    task :flush_sockets, :roles => :app do
      run "rm -f #{File.join(shared_path, "sockets", "puma.sock")}"
      run "rm -f #{File.join(shared_path, "sockets", "pumactl.sock")}"
    end
   
    desc "|capistrano-recipes| Shows puma status"
    task :status, :roles => :app do
      run puma_status_cmd
    end
    # ???????????????
    # desc "|capistrano-recipes| Tail puma log file" 
    # task :tail, :roles => :app do
    #   run "tail -f #{shared_path}/log/puma.log" do |channel, stream, data|
    #     puts "#{channel[:host]}: #{data}"
    #     break if stream == :err
    #   end
    # end

    desc <<-EOF
    |capistrano-recipes| Parses the configuration file through ERB to fetch our variables and \
    uploads the result to #{puma_remote_config}, to be loaded by whoever is booting \
    up the puma.
    EOF
    task :setup, :roles => :app , :except => { :no_release => true } do
      puma.flush_sockets
      commands = []
      commands << "mkdir -p #{sockets_path}"
      commands << "chown #{user}:#{group} #{sockets_path} -R" 
      commands << "chmod +rw #{sockets_path}"
      
      run commands.join(" && ")
      generate_config(puma_local_config, puma_remote_config)
    end
  end
  
  after 'deploy:setup' do
    if Capistrano::CLI.ui.agree("Create puma configuration file? [Yn]")
      puma.setup
    end
  end if is_using('puma',:app_server)
end
