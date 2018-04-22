require 'rails_helper'
require 'thread'

RSpec.describe "throttleable", type: :controller do
  controller ApplicationController do
    include Throttleable
    before_action :throttle

    def clear_queues
      synchronize { self.class.queues.clear }
    end

    def index
      render plain: 'ok'
    end
  end

  let!(:semaphore)      { Mutex.new }
  let(:throttle_window) { Rails.configuration.throttle_window.to_f }
  let(:request_count)   { Rails.configuration.throttle_request_count }
  let(:slow_velocity)   { throttle_window / request_count }

  # Perform :index upon throttled controller. Provide a user_agent for
  # ip/user agent fingerprinting. Otherwise, use cooked fingerprinting.
  def perform user_agent = nil
    request_count.times do
      semaphore.synchronize do
        request.user_agent = user_agent if user_agent
        get :index
        expect(response).to have_http_status 200
        expect(response.body).to eq 'ok'
      end
      yield if block_given?
    end
  end

  before { controller.clear_queues }

  context 'when cookie-disabled agent' do
    context "when requests' velocity is slower than throttle threshold" do
      it 'should return statuses 200' do
        perform('agent/1') { sleep slow_velocity }
      end
    end

    context "when requests' velocity is faster than throttle threshold" do
      it 'should return status 429' do
        perform 'agent/2'
        get :index
        expect(response).to have_http_status 429
        expect(response.body).to be_empty
      end
    end
  end

  context 'when cookie-enable agent' do
    it 'should set `_id` cookiue' do
      get :index
      expect(response.cookies).to include "_id"
    end

    context "when requests' velocity is slower than throttle threshold" do
      it 'should return statuses 200' do
        perform { sleep slow_velocity }
      end
    end

    context "when requests' velocity is faster than throttle threshold" do
      it 'should return status 429' do
        perform
        get :index
        expect(response).to have_http_status 429
        expect(response.body).to be_empty
      end
    end
  end

  # This spec tests that requests on two threads are isolated. However,
  # it fails since RSpec is not thread safe. The request object and its cookies
  # are shared between threads.
  xcontext 'when multiple requests are received simultaneously' do
    it 'should identify requests via user_agent and remote_ip headers' do
      slow_requests = Thread.new do
        perform('agent/1') { sleep slow_velocity }
        semaphore.synchronize do
          get :index
          expect(response).to have_http_status 200
        end
      end

      fast_requests = Thread.new do
        perform('agent/2')
        semaphore.synchronize do
          get :index
          expect(response).to have_http_status 429
        end
      end

      [ slow_requests, fast_requests ].each { |thread| thread.join }
    end
  end
end
