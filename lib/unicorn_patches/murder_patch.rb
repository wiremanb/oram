# frozen_string_literal: true

module Unicorn
  class HttpServer
    # forcibly terminate all workers that haven't checked in in timeout seconds.  The timeout is implemented using an unlinked File
    def murder_lazy_workers
      next_sleep = @timeout - 1
      now = time_now.to_i
      @workers.dup.each_pair do |wpid, worker|
        tick = worker.tick
        tick.zero? and next # skip workers that haven't processed any clients
        diff = now - tick
        tmp = @timeout - diff

        # monkey patch begins here
        if tmp < 2
          logger.error "worker=#{worker.nr} PID:#{wpid} running too long " \
                       "(#{diff}s), sending TERM"
          kill_worker(:TERM, wpid)
        end
        # end of monkey patch

        if tmp >= 0
          next_sleep > tmp and next_sleep = tmp
          next
        end
        next_sleep = 0
        logger.error "worker=#{worker.nr} PID:#{wpid} timeout " \
                     "(#{diff}s > #{@timeout}s), killing"
        kill_worker(:KILL, wpid) # take no prisoners for timeout violations
      end
      next_sleep <= 0 ? 1 : next_sleep
    end
  end
end
