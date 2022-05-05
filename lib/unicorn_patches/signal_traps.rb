# frozen_string_literal: true

%w(TERM USR2).each do |sig|
  Signal.trap(sig) do
    pid = Process.pid
    prefix = "[unicorn_murder_logger] pid: #{pid}"
    warn("#{prefix} Received #{sig} at #{Time.now}. Dumping threads:")
    Thread.list.each do |t|
      trace = t.backtrace.join("\n#{prefix}")
      warn("#{prefix} #{trace}")
      warn("#{prefix} ---")
    end
    warn("#{prefix} -------------------")
  end
end

