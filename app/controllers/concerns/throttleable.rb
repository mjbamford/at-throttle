require 'digest/sha1'

module Throttleable
  extend ActiveSupport::Concern

  included do
    class RateLimitError < StandardError; end

    @semaphore = Mutex.new
    @queues = {}

    class << self
      attr_reader :semaphore, :queues
    end

    before_action :set_throttle
    before_action :set_fingerprint_header, unless: -> { Rails.env.production? }

    rescue_from RateLimitError do
      head :too_many_requests
    end
  end

  private

  def set_throttle
    self.class.semaphore.synchronize do
      time_now = Time.now.to_f
      config = Rails.configuration
      queues = self.class.queues
      queue = (queues[fingerprint] ||= [])

      queue << time_now
      if queue.length > config.throttle_request_count
        time_at_window_head = queue.shift
        if (time_now - time_at_window_head) < config.throttle_window
          raise RateLimitError
        end
      end
    end
  end

  def set_fingerprint_header
    response.set_header 'X-Correlation-Id', fingerprint
  end

  def fingerprint
    @fingerprint ||= begin
      seed = request.remote_ip + request.user_agent
      Digest::SHA1.hexdigest seed
    end
  end
end
