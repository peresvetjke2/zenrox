require "net/http"
require "uri"

module Platform
  class TelegramClient
    def initialize(config:, http: Net::HTTP)
      @config = config
      @http = http
    end

    def send_message(chat_id:, text:)
      return false if config.bot_token.blank?

      response = http.post(
        endpoint_uri,
        JSON.dump(chat_id:, text:),
        "Content-Type" => "application/json"
      )

      response.is_a?(Net::HTTPSuccess)
    rescue StandardError
      false
    end

    private

    attr_reader :config, :http

    def endpoint_uri
      URI("https://api.telegram.org/bot#{config.bot_token}/sendMessage")
    end
  end
end
