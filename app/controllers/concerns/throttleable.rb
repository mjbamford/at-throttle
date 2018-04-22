require 'digest/sha1'
require 'securerandom'

module Throttleable
  extend ActiveSupport::Concern

  included do
    class RateLimitError < StandardError; end

    @semaphore = Mutex.new
    @queues = {}

    class << self
      attr_reader :semaphore, :queues
    end

    rescue_from RateLimitError do
      head :too_many_requests
    end
  end

  private

  def throttle
    synchronize do
      time_now = Time.now.to_f
      config = Rails.configuration
      queues = self.class.queues

      # Find the queue of previous requests that have the same fingerprint as
      # the current request. Prefer cookie over ip/user_agent fingerprinting.
      id, sha = fingerprints
      queue = queues[id] || queues[sha] || Array.new
      queues[id] = queues[sha] = queue

      # Push the current time onto the request's queue. If the number
      # of requests (with the same fingerprint) exceeds the throttle limit,
      # check the time window. Raise a RateLimitError if velocity has been
      # exceeded.
      queue << time_now
      if queue.length > config.throttle_request_count
        time_at_window_head = queue.shift
        if (time_now - time_at_window_head) < config.throttle_window
          raise RateLimitError
        end
      end
    end
  end

  def fingerprints
    id = (cookies["_id"] ||= SecureRandom.uuid)
    seed = request.remote_ip + request.user_agent
    digest = Digest::SHA1.hexdigest seed
    [ id, request.user_agent ]
  end

  def synchronize &block
    self.class.semaphore.synchronize &block
  end
end
