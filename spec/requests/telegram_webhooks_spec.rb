require "rails_helper"

RSpec.describe "POST /telegram/webhook", type: :request do
  let(:config) do
    Platform::TelegramConfig.new(
      env: {},
      bot_token: "test-bot-token",
      secret_token: "test-secret",
      allowed_chat_id: "42"
    )
  end

  let(:client) { instance_double(Platform::TelegramClient, send_message: true) }

  before do
    allow(Platform::TelegramConfig).to receive(:current).and_return(config)
    allow(Platform::TelegramClient).to receive(:new).with(config: config).and_return(client)
  end

  it "captures a supported Telegram text message and replies with the accepted verdict" do
    expect do
      post "/telegram/webhook",
        params: telegram_update(text: "купить молоко"),
        as: :json,
        headers: { "X-Telegram-Bot-Api-Secret-Token" => "test-secret" }
    end.to change(Task, :count).by(1)

    expect(response).to have_http_status(:no_content)

    task = Task.order(:id).last

    expect(task).to have_attributes(
      body: "купить молоко",
      source_text: "купить молоко",
      status: "open",
      operation_id: "telegram:update:1001"
    )
    expect(client).to have_received(:send_message).with(chat_id: 42, text: "Задача сохранена.")

    write_evidence(
      "chk-01/telegram-success.json",
      {
        request: telegram_update(text: "купить молоко"),
        task: task.attributes.slice("id", "body", "status", "source_text", "operation_id"),
        reply: "Задача сохранена."
      },
      feature: "ft-003"
    )
  end

  it "does not create a duplicate task when the same update is retried after an outbound failure" do
    allow(client).to receive(:send_message).and_return(false, true)

    expect do
      post "/telegram/webhook",
        params: telegram_update(text: "позвонить маме", update_id: 1002),
        as: :json,
        headers: { "X-Telegram-Bot-Api-Secret-Token" => "test-secret" }
    end.to change(Task, :count).by(1)

    expect(response).to have_http_status(:bad_gateway)

    expect do
      post "/telegram/webhook",
        params: telegram_update(text: "позвонить маме", update_id: 1002),
        as: :json,
        headers: { "X-Telegram-Bot-Api-Secret-Token" => "test-secret" }
    end.not_to change(Task, :count)

    expect(response).to have_http_status(:no_content)
    expect(client).to have_received(:send_message).twice

    task = Task.find_by!(operation_id: "telegram:update:1002")

    write_evidence(
      "chk-02/telegram-retry.json",
      {
        request: telegram_update(text: "позвонить маме", update_id: 1002),
        task: task.attributes.slice("id", "body", "status", "source_text", "operation_id"),
        delivery_attempts: 2
      },
      feature: "ft-003"
    )
  end

  it "rejects an invalid secret and does not process the update" do
    expect do
      post "/telegram/webhook",
        params: telegram_update(text: "купить молоко", update_id: 1003),
        as: :json,
        headers: { "X-Telegram-Bot-Api-Secret-Token" => "wrong-secret" }
    end.not_to change(Task, :count)

    expect(response).to have_http_status(:unauthorized)
    expect(client).not_to have_received(:send_message)
  end

  it "replies with an explanatory message for non-text updates" do
    expect do
      post "/telegram/webhook",
        params: telegram_update(text: nil, update_id: 1004),
        as: :json,
        headers: { "X-Telegram-Bot-Api-Secret-Token" => "test-secret" }
    end.not_to change(Task, :count)

    expect(response).to have_http_status(:no_content)
    expect(client).to have_received(:send_message).with(
      chat_id: 42,
      text: "Сейчас я умею принимать только текстовые сообщения."
    )

    write_evidence(
      "chk-03/telegram-guards.json",
      {
        invalid_secret_status: "unauthorized",
        non_text_reply: "Сейчас я умею принимать только текстовые сообщения."
      },
      feature: "ft-003"
    )
  end

  it "ignores updates from non-private chats" do
    expect do
      post "/telegram/webhook",
        params: telegram_update(text: "купить молоко", update_id: 1005, chat_type: "group"),
        as: :json,
        headers: { "X-Telegram-Bot-Api-Secret-Token" => "test-secret" }
    end.not_to change(Task, :count)

    expect(response).to have_http_status(:no_content)
    expect(client).not_to have_received(:send_message)
  end

  it "ignores updates from chats outside the configured allow-list" do
    expect do
      post "/telegram/webhook",
        params: telegram_update(text: "купить молоко", update_id: 1006, chat_id: 777),
        as: :json,
        headers: { "X-Telegram-Bot-Api-Secret-Token" => "test-secret" }
    end.not_to change(Task, :count)

    expect(response).to have_http_status(:no_content)
    expect(client).not_to have_received(:send_message)

    write_evidence(
      "chk-03/telegram-guards.json",
      {
        invalid_secret_status: "unauthorized",
        non_text_reply: "Сейчас я умею принимать только текстовые сообщения.",
        group_chat_status: "no_content",
        disallowed_chat_status: "no_content"
      },
      feature: "ft-003"
    )
  end

  def telegram_update(text:, update_id: 1001, chat_id: 42, chat_type: "private")
    message = {
      message_id: 9,
      chat: {
        id: chat_id,
        type: chat_type
      }
    }

    message[:text] = text if text

    {
      update_id:,
      message:
    }
  end
end
