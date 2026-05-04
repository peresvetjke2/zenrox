require "rails_helper"

RSpec.describe "POST /capture", type: :request do
  describe "supported input" do
    it "creates one open task per supported message and returns a confirmation" do
      supported_corpus = [ "купить молоко", "позвонить маме" ]

      expect do
        supported_corpus.each do |text|
          post "/capture", params: { text: }

          expect(response).to have_http_status(:created)

          payload = response.parsed_body
          task = Task.order(:id).last

          expect(task.body).to eq(text)
          expect(task.source_text).to eq(text)
          expect(task.status).to eq("open")
          expect(payload).to include(
            "status" => "accepted",
            "message" => "Задача сохранена."
          )
          expect(payload.fetch("task")).to include(
            "id" => task.id,
            "body" => text,
            "status" => "open"
          )
        end
      end.to change(Task, :count).by(2)

      tasks = Task.order(:id).map { |task| task.attributes.slice("id", "body", "status", "source_text", "operation_id") }

      write_evidence("chk-01/request-success.json", { supported_corpus:, tasks: })
    end
  end

  describe "unsupported input" do
    it "returns explanatory rejection and does not persist a task" do
      expect do
        post "/capture", params: { text: "купить молоко и позвонить маме" }
      end.not_to change(Task, :count)

      expect(response).to have_http_status(:unprocessable_content)

      payload = response.parsed_body

      expect(payload).to include(
        "status" => "rejected",
        "message" => "Не получилось сохранить задачу автоматически.",
        "reason" => "В сообщении больше одного действия."
      )
      expect(payload.fetch("hint")).to be_present
    end
  end

  describe "failed save" do
    it "does not return a success-like confirmation when persistence fails" do
      allow(Capture::TaskWriter).to receive(:call).and_return(nil)

      expect do
        post "/capture", params: { text: "позвонить маме" }
      end.not_to change(Task, :count)

      expect(response).to have_http_status(:internal_server_error)

      payload = response.parsed_body

      expect(payload).to include(
        "status" => "failed",
        "message" => "Не удалось сохранить задачу.",
        "reason" => "Сохранение задачи не завершилось успешно."
      )

      write_evidence(
        "chk-03/request-failed-save.json",
        {
          request: { text: "позвонить маме" },
          response: payload
        }
      )
    end
  end
end
