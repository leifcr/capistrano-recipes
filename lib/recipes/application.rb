require "bundler/capistrano"
require "rvm/capistrano"

Capistrano::Configuration.instance.load do
  # User settings
  set :user, 'deploy'   unless exists?(:user)
  set :group,'www-data' unless exists?(:group)
  
  # HACK
  # Server settings
  #set :app_server, :unicorn       unless exists?(:app_server)
  #set :web_server, :nginx         unless exists?(:web_server)
  puts "Please define app_server" unless exists?(:app_server)
  puts "Please define web_server" unless exists?(:web_server)

  set :runner, user               unless exists?(:runner)
  set :application_port, 80        unless exists?(:application_port)

  set :application_uses_ssl, false unless exists?(:application_uses_ssl)
  set :application_port_ssl, 443   unless exists?(:application_port_ssl)
  
  # Database settings
  set :database, :mysql unless exists?(:database)
  
  # SCM settings
  set :scm, :git
  set :branch, 'master' unless exists?(:branch)
  puts "Missing deploy_to path for application... cannot deploy to nil" unless exists?(:deploy_to)
  set :deploy_via, :remote_cache
  set :keep_releases, 3
  set :git_enable_submodules, true
  set :rails_env, 'production' unless exists?(:rails_env)
  set :use_sudo, false

  # Git settings for capistrano
  default_run_options[:pty] = true 
  ssh_options[:forward_agent] = true
  
  # RVM settings
  # set :using_rvm, true unless exists?(:using_rvm)
  
  # Bundler settings
  set :bundle_flags, "--deployment --without=development test" unless exists?(:bundle_flags)

  # # RVM stuff
  # namespace :rvm do
  #   task :trust_rvmrc do
  #     run "rvm rvmrc trust #{release_path}"
  #   end
  # end

  # after "deploy", "rvm:trust_rvmrc"
  
  # Daemons settings
  # The unix socket that unicorn will be attached to.
  # Also, nginx will upstream to this guy.
  # The *nix place for socks is /var/run, so we should probably put it there
  # Make sure the runner can access this though.
  set :sockets_path, "/var/run/#{application}_#{rails_env}" unless exists?(:sockets_path)
  
  # Just to be safe, put the pid somewhere that survives deploys. shared/pids is
  # a good choice as any.
  set(:pids_path) { File.join(shared_path, "pids") } unless exists?(:pids_path)
  
  set :monitorer, 'bluepill' unless exists?(:monitorer)
end
