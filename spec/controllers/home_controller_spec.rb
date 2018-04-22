require 'rails_helper'

RSpec.describe HomeController, type: :controller do
  describe "#index" do
    it "should return status 200" do
      get :index
      expect(response).to have_http_status 200
      expect(response.body).to eq 'ok'
    end
  end
end
