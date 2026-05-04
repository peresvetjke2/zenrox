class CapturesController < ApplicationController
  def create
    result = Capture::ProcessMessage.call(text: capture_params[:text])

    render json: result.as_json, status: result.http_status
  end

  private

  def capture_params
    params.permit(:text)
  end
end
