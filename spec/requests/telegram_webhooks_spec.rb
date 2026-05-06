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
      "chk-01/telegram-capture-handoff.json",
      {
        request: telegram_update(text: "купить молоко"),
        task: task.attributes.slice("id", "body", "status", "source_text", "operation_id"),
        reply: "Задача сохранена."
      },
      feature: "ft-004"
    )
  end

  it "routes retrieval paraphrases to open-tasks listing without creating a task" do
    Task.create!(
      body: "купить молоко",
      source_text: "купить молоко",
      operation_id: "ft-002-open-telegram-1",
      status: "open"
    )
    Task.create!(
      body: "сдать отчет",
      source_text: "сдать отчет",
      operation_id: "ft-002-open-telegram-2",
      status: "open"
    )
    Task.create!(
      body: "позвонить маме",
      source_text: "позвонить маме",
      operation_id: "ft-002-done-telegram-1",
      status: "done"
    )

    expect do
      post "/telegram/webhook",
        params: telegram_update(text: "покажи мне мои задачи", update_id: 1100),
        as: :json,
        headers: { "X-Telegram-Bot-Api-Secret-Token" => "test-secret" }
    end.not_to change(Task, :count)

    expect(response).to have_http_status(:no_content)

    expected_reply = <<~TEXT.chomp
      Открытые задачи:
      - купить молоко
      - сдать отчет
    TEXT

    expect(client).to have_received(:send_message).with(chat_id: 42, text: expected_reply)

    write_evidence(
      "chk-04/telegram-retrieval-handoff.json",
      {
        request: telegram_update(text: "покажи мне мои задачи", update_id: 1100),
        open_task_bodies: Task.open_for_retrieval.pluck(:body),
        reply: expected_reply
      },
      feature: "ft-004"
    )
  end

  it "returns a pending-executor reply for an unambiguous lifecycle intent without mutating task state" do
    Task.create!(
      body: "купить молоко",
      source_text: "купить молоко",
      operation_id: "ft-004-telegram-lifecycle-1",
      status: "open"
    )
    before_snapshot = Task.order(:id).pluck(:id, :body, :status)

    expect do
      post "/telegram/webhook",
        params: telegram_update(text: "можешь закрыть задачу купить молоко пожалуйста", update_id: 1200),
        as: :json,
        headers: { "X-Telegram-Bot-Api-Secret-Token" => "test-secret" }
    end.not_to change(Task, :count)

    expect(response).to have_http_status(:no_content)
    expect(Task.order(:id).pluck(:id, :body, :status)).to eq(before_snapshot)
    expect(client).to have_received(:send_message).with(
      chat_id: 42,
      text: "Не выполнил действие: задачу для завершения удалось определить, но автоматическое закрытие пока не реализовано."
    )

    write_evidence(
      "chk-05/telegram-lifecycle-pending.json",
      {
        request: telegram_update(text: "можешь закрыть задачу купить молоко пожалуйста", update_id: 1200),
        before: before_snapshot,
        after: Task.order(:id).pluck(:id, :body, :status),
        reply: "Не выполнил действие: задачу для завершения удалось определить, но автоматическое закрытие пока не реализовано."
      },
      feature: "ft-004"
    )
  end

  it "returns clarification for mixed-intent input without side effects" do
    expect do
      post "/telegram/webhook",
        params: telegram_update(text: "покажи задачи и закрой первую", update_id: 1201),
        as: :json,
        headers: { "X-Telegram-Bot-Api-Secret-Token" => "test-secret" }
    end.not_to change(Task, :count)

    expect(response).to have_http_status(:no_content)
    expect(client).to have_received(:send_message).with(
      chat_id: 42,
      text: "Не выполнил действие: в одном сообщении получилось несколько запросов. Отправьте одну команду за раз."
    )
  end

  it "returns clarification for missing lifecycle target without side effects" do
    expect do
      post "/telegram/webhook",
        params: telegram_update(text: "готово", update_id: 1205),
        as: :json,
        headers: { "X-Telegram-Bot-Api-Secret-Token" => "test-secret" }
    end.not_to change(Task, :count)

    expect(response).to have_http_status(:no_content)
    expect(client).to have_received(:send_message).with(
      chat_id: 42,
      text: "Не выполнил действие: уточните, какую задачу нужно завершить."
    )
  end

  it "returns unsupported for out-of-scope input without creating a task" do
    expect do
      post "/telegram/webhook",
        params: telegram_update(text: "что я говорил про корову месяц назад?", update_id: 1202),
        as: :json,
        headers: { "X-Telegram-Bot-Api-Secret-Token" => "test-secret" }
    end.not_to change(Task, :count)

    expect(response).to have_http_status(:no_content)
    expect(client).to have_received(:send_message).with(
      chat_id: 42,
      text: "Не выполнил действие: запрос пока не поддерживается в этом канале."
    )

    write_evidence(
      "chk-03/telegram-safe-non-success.json",
      {
        mixed_reply: "Не выполнил действие: в одном сообщении получилось несколько запросов. Отправьте одну команду за раз.",
        unsupported_reply: "Не выполнил действие: запрос пока не поддерживается в этом канале."
      },
      feature: "ft-004"
    )
  end

  it "preserves downstream capture rejection formatting after routing handoff" do
    rejection = Capture::Result.rejected(
      reason: "В сообщении больше одного действия.",
      hint: "Разбейте сообщение на одну задачу за раз."
    )
    allow(Capture::ProcessMessage).to receive(:call).and_return(rejection)

    expect do
      post "/telegram/webhook",
        params: telegram_update(text: "купить молоко", update_id: 1203),
        as: :json,
        headers: { "X-Telegram-Bot-Api-Secret-Token" => "test-secret" }
    end.not_to change(Task, :count)

    expect(response).to have_http_status(:no_content)
    expect(client).to have_received(:send_message).with(
      chat_id: 42,
      text: <<~TEXT.chomp
        Не получилось сохранить задачу автоматически.
        В сообщении больше одного действия.
        Разбейте сообщение на одну задачу за раз.
      TEXT
    )
  end

  it "preserves downstream retrieval failure messaging after routing handoff" do
    allow(Retrieval::ListOpenTasks).to receive(:call).and_return(Retrieval::Result.failure)

    expect do
      post "/telegram/webhook",
        params: telegram_update(text: "какие у меня задачи?", update_id: 1204),
        as: :json,
        headers: { "X-Telegram-Bot-Api-Secret-Token" => "test-secret" }
    end.not_to change(Task, :count)

    expect(response).to have_http_status(:no_content)
    expect(client).to have_received(:send_message).with(
      chat_id: 42,
      text: "Не удалось получить список открытых задач."
    )

    write_evidence(
      "chk-04/telegram-downstream-passthrough.json",
      {
        capture_rejection_reply: [
          "Не получилось сохранить задачу автоматически.",
          "В сообщении больше одного действия.",
          "Разбейте сообщение на одну задачу за раз."
        ].join("\n"),
        retrieval_failure_reply: "Не удалось получить список открытых задач."
      },
      feature: "ft-004"
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
