class TelegramWebhooksController < ApplicationController
  def create
    result = Interaction::TelegramWebhook.call(
      payload: params.to_unsafe_h,
      secret_token: request.headers["X-Telegram-Bot-Api-Secret-Token"]
    )

    head result.http_status
  end
end
