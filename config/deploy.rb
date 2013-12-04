require "bundler/capistrano"
require "rvm/capistrano"
require "dotenv/capistrano"

# require 'capistrano-unicorn'

set :user,        'vagrant'
set :application, "feedbin"
set :use_sudo,    false

set :scm,           :git
set :repository,    "https://github.com/gcimmino/feedbin.git"
set :branch,        'master'
set :keep_releases, 5
set :deploy_via,    :remote_cache

set :ssh_options, { forward_agent: true }
set :deploy_to,   "/home/#{user}/apps/#{application}"

# # TODO see if this can be removed if `sudo bundle` stops failing
# set :bundle_cmd, "/usr/local/rbenv/shims/bundle"

# Gets rid of trying to link public/* directories
set :normalize_asset_timestamps, false

# set :unicorn_pid, "#{shared_path}/pids/unicorn.pid"
# set :unicorn_bundle, bundle_cmd


# uWSGI configuration vars
set :uwsgi_config_file, "uwsgi.ini"
set :uwsgi_pid_file, "pids/uwsgi.pid"

set :assets_role, [:app]

role :app, "myfeedbin.com"
role :worker, "myfeedbin.com"

# default_run_options[:pty] = true
# default_run_options[:shell] = '/bin/bash --login'

# namespace :foreman do
#
#   task :export_worker, roles: :worker do
#     foreman_export = "foreman export --app #{application} --user #{user} --concurrency worker=3,worker_slow=2,clock=1 --log #{shared_path}/log upstart /etc/init"
#     run "cd #{current_path} && sudo #{bundle_cmd} exec #{foreman_export}"
#   end
#
#   desc 'Start the application services'
#   task :start do
#     run "sudo start #{application}"
#   end
#
#   desc 'Stop the application services'
#   task :stop do
#     run "sudo stop #{application}"
#   end
#
#   desc 'Restart worker services'
#   task :restart_worker, roles: :worker  do
#     run "sudo start #{application} || sudo restart #{application} || true"
#   end
#
#   desc "Zero-downtime restart of Unicorn"
#   task :restart_web, roles: :web  do
#     unicorn.restart
#   end
#
# end

namespace :uwsgi do
  desc "Setup uwsgi for application"
  task :setup do
    run "mkdir -p #{shared_path}/run #{shared_path}/config"
    uwsgi::config_upload
  end

  desc "Upload #{uwsgi_config_file}"
  task :config_upload do
    upload "config/#{uwsgi_config_file}", "#{shared_path}/config/#{uwsgi_config_file}", :via => :scp
    # config_ext = File.extname(uwsgi_config_file)
    # run "sudo ln -fs #{shared_path}/config/#{uwsgi_config_file} /etc/uwsgi/apps-enabled/#{stage}_#{application}#{config_ext}"
  end

  desc "Start uwsgi application"
  task :start do
    run "#{try_sudo} uwsgi #{shared_path}/config/#{uwsgi_config_file}"
  end

  desc "Status uwsgi application"
  task :status do
    run "#{try_sudo} ps l `cat #{shared_path}/#{uwsgi_pid_file}`"
  end

  desc "Stop uwsgi application"
  task :stop do
    run "#{try_sudo} uwsgi --stop #{shared_path}/#{uwsgi_pid_file}"
  end

  desc "Reload uwsgi application"
  task :reload do
    run "#{try_sudo} uwsgi --reload #{shared_path}/#{uwsgi_pid_file}"
  end

  desc "Tail uwsgi log"
  task :log do
    run "tailf #{current_path}/log/uwsgi.log"
  end
end

namespace :deploy do
  desc 'Start the application services'
  task :start do
    uwsgi.start
  end

  desc 'Stop the application services'
  task :stop do
    uwsgi.stop
  end
end

namespace :dotenv do
  task :copy do
    # upload "config/env_production", "#{shared_path}/config/.env", :via => :scp
    run "#{try_sudo} cp #{release_path}/config/env_production #{shared_path}/.env"

  end
end

namespace :db do
  desc "Create the database"
  task :create do
    puts "\n\n=== Creating the Database! ===\n\n"
    run "createdb feedbin_production"
    # run "cd #{current_path} && bundle exec rake db:schema: RAILS_ENV=production"
  end
end

# after 'deploy:update_code', 'dotenv:link'
before 'dotenv:symlink', 'dotenv:copy'
after 'deploy:setup', 'uwsgi:setup'
after 'deploy:update',  'deploy:migrate'
after 'deploy:restart', 'uwsgi:reload'


