current_directory = "/app"
num_workers = ENV['UNICORNS'] ? ENV['UNICORNS'].to_i : 16
working_directory current_directory
listen 8080
worker_processes num_workers
timeout 60

preload_app true
if GC.respond_to?(:copy_on_write_friendly=)
  GC.copy_on_write_friendly = true
end

# Stop rendering if the client disconnects
check_client_connection true

# Setup tagged logging
unicorn_logger = ::Logger.new($stdout)
unicorn_logger.formatter = proc { |severity, time, progname, msg| "[unicorn_logger] #{msg}\n" }
logger unicorn_logger

before_exec do |_|
  ENV["BUNDLE_GEMFILE"] = File.join(current_directory, "Gemfile")
end

# This happens in the master before we fork off the workers.  More needs to be done here.
before_fork do |server, worker|
  ActiveRecord::Base.connection.disconnect! if defined?(ActiveRecord::Base)
  # Clear any connections to shards w/ Octopus
  # Disabled until bugs with Octopus are sorted out
  # ActiveRecord::Base.connection.clear_all_connections! if defined?(ActiveRecord::Base) && defined?(Octopus)

  # The following is only recommended for memory/DB-constrained
  # installations.  It is not needed if your system can house
  # twice as many worker_processes as you have configured.

  # This allows a new master process to incrementally
  # phase out the old master process with SIGTTOU to avoid a
  # thundering herd (especially in the "preload_app false" case)
  # when doing a transparent upgrade.  The last worker spawned
  # will then kill off the old master process with a SIGQUIT.
  old_pid = "#{server.config[:pid]}.oldbin"
  if old_pid != server.pid
    begin
      sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
      Process.kill(sig, File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end

  # Throttle the master from forking too quickly by sleeping.  Due
  # to the implementation of standard Unix signal handlers, this
  # helps (but does not completely) prevent identical, repeated signals
  # from being lost when the receiving process is busy.
  sleep 1
end

require File.join(current_directory, 'lib', 'unicorn_patches', 'murder_patch')
# This happens once the worker has been forked.
after_fork do |server, worker|
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord::Base)
  # Disabled until bugs with Octopus are sorted out
  # ActiveRecord::Base.connection.initialize_shards(Octopus.config) if defined?(Octopus)
  Rails.cache.reset if Rails.cache.respond_to?(:reset)
  require File.join(current_directory, 'lib', 'unicorn_patches', 'signal_traps')
end
