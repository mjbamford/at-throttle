class HomeController < ApplicationController
  include Throttleable
  before_action :throttle, only: :index

  def index
    render plain: 'ok'
  end
end
