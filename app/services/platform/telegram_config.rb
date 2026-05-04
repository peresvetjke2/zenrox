module Platform
  class TelegramConfig
    def self.current
      new
    end

    def initialize(env: ENV, bot_token: nil, secret_token: nil, allowed_chat_id: nil)
      @env = env
      @bot_token = bot_token
      @secret_token = secret_token
      @allowed_chat_id = allowed_chat_id
    end

    def allowed_chat?(chat_id)
      return false if chat_id.blank?
      return true if allowed_chat_id.blank?

      allowed_chat_id.to_s == chat_id.to_s
    end

    def bot_token
      @bot_token.presence || env["ZENROX_TELEGRAM_BOT_TOKEN"].presence
    end

    def secret_token
      @secret_token.presence || env["ZENROX_TELEGRAM_SECRET_TOKEN"].presence
    end

    def secret_token_valid?(provided_token)
      return true if secret_token.blank?
      return false if provided_token.blank?

      ActiveSupport::SecurityUtils.secure_compare(provided_token.to_s, secret_token.to_s)
    end

    private

    attr_reader :allowed_chat_id, :env
  end
end
