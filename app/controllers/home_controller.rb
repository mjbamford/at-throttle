class HomeController < ApplicationController
  include Throttle

  def index
    render plain: self.class.queues.inspect
  end
end
