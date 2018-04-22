class HomeController < ApplicationController
  include Throttleable

  def index
    Rails.logger.info self.class.queues.inspect
    render plain: 'ok'
  end
end
