require 'thread'
require 'digest/sha1'

class HomeController < ApplicationController
  class RateLimitError < StandardError; end

  OK = 'ok'
  THROTTLE_WINDOW = 5 # seconds
  THROTTLE_REQUEST_COUNT = 5

  @semaphore = Mutex.new
  @queues = {}

  before_action :throttle, only: :index

  rescue_from RateLimitError do
    head :too_many_requests
  end

  def index
    render plain: self.class.queues.inspect
  end

  class << self
    attr_reader :semaphore, :queues
  end

  private

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
    @fingerprint ||= begin
      seed = request.remote_ip + request.user_agent
      Digest::SHA1.hexdigest seed
    end
  end
end
