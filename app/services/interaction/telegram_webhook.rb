module Interaction
  class TelegramWebhook
    Response = Struct.new(:http_status, keyword_init: true)

    def self.call(payload:, secret_token:, config: Platform::TelegramConfig.current, client: Platform::TelegramClient.new(config:))
      new(payload:, secret_token:, config:, client:).call
    end

    def initialize(payload:, secret_token:, config:, client:)
      @payload = normalize_payload(payload)
      @secret_token = secret_token
      @config = config
      @client = client
    end

    def call
      return Response.new(http_status: :unauthorized) unless config.secret_token_valid?(secret_token)

      return Response.new(http_status: :no_content) unless private_message?
      return Response.new(http_status: :no_content) unless config.allowed_chat?(chat_id)

      reply_text = if message_text.present?
        capture_result = Capture::ProcessMessage.call(text: message_text, operation_id: operation_id)
        format_capture_reply(capture_result)
      else
        "Сейчас я умею принимать только текстовые сообщения."
      end

      return Response.new(http_status: :no_content) if client.send_message(chat_id:, text: reply_text)

      Response.new(http_status: :bad_gateway)
    end

    private

    attr_reader :client, :config, :payload, :secret_token

    def chat_id
      message.dig("chat", "id")
    end

    def format_capture_reply(result)
      lines = [ result.message ]
      lines << result.reason if result.reason.present?
      lines << result.hint if result.hint.present?
      lines.join("\n")
    end

    def message
      payload.fetch("message", {})
    end

    def message_text
      message["text"].to_s.strip
    end

    def normalize_payload(source)
      source.respond_to?(:to_h) ? source.to_h.deep_stringify_keys : {}
    end

    def operation_id
      update_id = payload["update_id"]
      return "telegram:update:#{update_id}" if update_id.present?

      "telegram:chat:#{chat_id}:message:#{message["message_id"]}"
    end

    def private_message?
      message.dig("chat", "type") == "private"
    end
  end
end
