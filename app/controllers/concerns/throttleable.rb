require 'digest/sha1'

module Throttleable
  extend ActiveSupport::Concern

  included do
    class RateLimitError < StandardError; end

    THROTTLE_WINDOW = 5 # seconds
    THROTTLE_REQUEST_COUNT = 5 # requests per window

    @semaphore = Mutex.new
    @queues = {}

    class << self
      attr_reader :semaphore, :queues
    end

    before_action :throttle

    rescue_from RateLimitError do
      head :too_many_requests
    end
  end

  def throttle
    self.class.semaphore.synchronize do
      time_now = Time.now.to_f
      queues = self.class.queues
      queue = (queues[fingerprint] ||= [])
      queue << time_now
      if queue.length > THROTTLE_REQUEST_COUNT
        time_at_window_head = queue.shift
        if (time_now - time_at_window_head) < THROTTLE_WINDOW
          raise RateLimitError
        end
      end
    end
  end

  def fingerprint
    seed = request.remote_ip + request.user_agent
    Digest::SHA1.hexdigest seed
  end
end
