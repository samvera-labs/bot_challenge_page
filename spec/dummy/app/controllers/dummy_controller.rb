class DummyController < ApplicationController

  def index
    render plain: "rendered action dummy#index"
  end

  # just give us download content-disposition headers to test that
  def download
    headers['content-disposition'] = "attachment; filename=\"file.txt\""
    render plain: "something"
  end
end
