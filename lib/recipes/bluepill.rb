Capistrano::Configuration.instance.load do  
  set(:bluepill_use_puma)        {true}   unless exists?(:bluepill_use_puma)
  set(:bluepill_use_delayed_job) {false}  unless exists?(:bluepill_use_delayed_job)
  set(:bluepill_local_init) { File.join(templates_path, "bluepill_init.conf.erb") } 
  set(:bluepill_local_init) { File.join(templates_path, "bluepill_init.conf.erb") } 
  set(:bluepill_remote_init) { File.join("/etc", "init", "bluepill_#{application}_#{rails_env}.conf") } 
  set(:bluepill_local_config) { File.join(templates_path, "bluepill.pill.erb") } 
  set(:bluepill_remote_config) { File.join(shared_path, "config", "master.pill") }

  set(:bluepill_base_dir) { File.join(shared_path, "bluepill") }  unless exists?(:bluepill_base_dir)

  set(:bluepill_puma_pid) { File.join(pids_path,"#{app_server}.pid") } unless exists?(:bluepill_puma_pid)
  set(:bluepill_puma_control_url) { File.join(shared_path, "sockets", "pumactl.sock") } unless exists?(:bluepill_puma_control_url)
  set(:bluepill_puma_state) { File.join(shared_path, "sockets", "puma.state") } unless exists?(:bluepill_puma_state)
  set(:bluepill_puma_config) { File.join(shared_path, "config", "puma.rb") } unless exists?(:bluepill_puma_config)

  set(:bluepill_working_dir) {"#{current_path}"} unless exists?(:bluepill_working_dir)
  set(:bluepill_app) {"#{application}_#{rails_env}"} unless exists?(:bluepill_app)
  set(:bluepill_start_grace_time)   { "20.seconds" } unless exists?(:bluepill_start_grace_time)
  set(:bluepill_stop_grace_time)    { "15.seconds" } unless exists?(:bluepill_stop_grace_time)
  set(:bluepill_restart_grace_time) { "25.seconds" } unless exists?(:bluepill_restart_grace_time)
  set(:bluepill_delayed_job_pid) { File.join(pids_path,"delayed_job.pid") } unless exists?(:bluepill_delayed_job_pid)

  set(:bluepill_use_default_base_dir) {false} unless exists?(:bluepill_use_default_base_dir)

  # def bluepill_remote_dir_exists?(full_path)
  #   'true' ==  capture("if [ -d /var/run/bluepill ]; then echo 'true'; fi").strip
  # end
  namespace :bluepill do
    desc "|capistrano-recipes| Create /var/run/bluepill with correct owner"
    task :create_var_run, :roles => [:app] do
      if 'true' !=  capture("if [[ -d /var/run/bluepill ]]; then echo 'true'; fi").strip
        sudo "mkdir -p /var/run/bluepill"
        sudo "sudo chown #{user}:#{group} /var/run/bluepill"
      end
    end

    desc "|capistrano-recipes| Create bluepill base dir in #{shared_path}"
    task :create_shared_base_dir, :roles => [:app] do
      run "mkdir -p #{bluepill_base_dir}"
    end

    desc "|capistrano-recipes| Stop processes that bluepill is monitoring and quit bluepill"
    task :quit, :roles => [:app] do
      args = exists?(:options) ? options : ''
      args += " --base-dir #{bluepill_base_dir}" unless bluepill_use_default_base_dir
      args += " --no-privileged"
      begin
        run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec bluepill #{bluepill_app} stop #{args}"
      rescue
        puts "Bluepill was unable to finish gracefully all the process.. (stop). Most likely not running..."
      ensure
        begin
          run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec bluepill #{bluepill_app} quit #{args}"
        rescue
          puts "Bluepill was unable to finish gracefully all the process.. (quit). Most likely not running..."
        end
      end
      sleep 5
    end

    desc "|capistrano-recipes| Load the pill from {your-app}/config/master.pill"
    task :init, :roles =>[:app] do
      args = exists?(:options) ? options : ''
      args += " --base-dir #{bluepill_base_dir}" unless bluepill_use_default_base_dir
      args += " --no-privileged"
      run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec bluepill load #{bluepill_remote_config} #{args}"
    end
 
    desc "|capistrano-recipes| Starts your previous stopped pill"
    task :start, :roles =>[:app] do
      args = exists?(:options) ? options : ''
      args += " --base-dir #{bluepill_base_dir}" unless bluepill_use_default_base_dir
      args += " --no-privileged"
      run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec bluepill load #{bluepill_remote_config} #{args}"
    end
    
    desc "|capistrano-recipes| Stops some bluepill monitored process"
    task :stop, :roles =>[:app] do
      args = exists?(:options) ? options : ''
      args += " --base-dir #{bluepill_base_dir}" unless bluepill_use_default_base_dir
      args += " --no-privileged"
      run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec bluepill #{bluepill_app} stop #{args}"
    end
    
    desc "|capistrano-recipes| Restarts the pill from {your-app}/config/master.pill"
    task :restart, :roles =>[:app] do
      args = exists?(:options) ? options : ''
      args += " --base-dir #{bluepill_base_dir}" unless bluepill_use_default_base_dir
      args += " --no-privileged"
      begin
        run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec bluepill #{bluepill_app} restart #{args}"
      rescue
        puts "-----------"
        puts "Bluepill was unable to restart... Trying quit and then start..."
        puts "-----------"
        bluepill.quit 
        bluepill.start 
      end

      # bluepill.quit 
      # bluepill.start 
    #   args = exists?(:options) ? options : ''
    #   #run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec bluepill #{bluepill_app} restart --no-privileged #{args}"
   end
 
    desc "|capistrano-recipes| Prints bluepills monitored processes statuses"
    task :status, :roles => [:app] do
      args = exists?(:options) ? options : ''
      args += " --base-dir #{bluepill_base_dir}" unless bluepill_use_default_base_dir
      args += " --no-privileged"
      run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec bluepill #{bluepill_app} status #{args}"
    end

    desc <<-EOF
    |capistrano-recipes| Parses the configuration file through ERB to fetch our variables and \
    uploads the result to #{bluepill_remote_config}, to be loaded by whoever is booting \
    up the bluepill watcher/monitorer
    EOF
    task :setup_config, :roles => :app , :except => { :no_release => true } do
      generate_config(bluepill_local_config, bluepill_remote_config)
    end

    desc "|capistrano-recipes| Create bluepill init file for ubuntu systems..."
    task :setup_init, :roles => :app , :except => { :no_release => true } do
      generate_config(bluepill_local_init, bluepill_remote_init, true)
    end
  end

  after 'deploy:setup' do
    bluepill.setup_config   if Capistrano::CLI.ui.agree("Create master.pill configuration file? [Yn]")
    bluepill.setup_init     if Capistrano::CLI.ui.agree("Create #{bluepill_remote_init} configuration file? [Yn]")
    if bluepill_use_default_base_dir
      bluepill.create_var_run if Capistrano::CLI.ui.agree("Create /var/run/bluepill directory? [Yn]")
    else
      bluepill.create_shared_base_dir
    end
  end if is_using('bluepill', :monitorer)

  # after "deploy:update" do 
  #   bluepill.quit 
  #   bluepill.start 
  # end if is_using('bluepill', :monitorer)
  #end if is_using_bluepill
end
