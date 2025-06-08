require "google/apis/drive_v3"
require "googleauth"
require "pdf-reader"
require "stringio"

class DocumentsController < ApplicationController
  before_action :authenticate

  require "openai"

def read
  file_id = params[:file_id]

  # Google Drive download (same as before)
  credentials = Google::Auth::ServiceAccountCredentials.make_creds(
    json_key_io: File.open(Rails.root.join("config", "service_account.json")),
    scope: [ "https://www.googleapis.com/auth/drive.readonly" ]
  )
  drive_service = Google::Apis::DriveV3::DriveService.new
  drive_service.authorization = credentials

  io = StringIO.new
  drive_service.get_file(file_id, download_dest: io)
  io.rewind

  reader = PDF::Reader.new(io)
  text = reader.pages.first(10).map(&:text).join("\n").encode("UTF-8", invalid: :replace, undef: :replace, replace: "")

  # Summarize with OpenAI
  client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
  summary = client.chat(
    parameters: {
      model: "gpt-4",
      messages: [
        { role: "system", content: "You're a compliance analyst assistant." },
        { role: "user", content: "Summarize the key regulatory takeaways from this document:\n\n#{text}" }
      ],
      temperature: 0.4
    }
  )

  client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

summary = client.chat(
  parameters: {
    model: "gpt-4",
    messages: [
      { role: "system", content: "You are a compliance analyst. Summarize this regulatory document in clear, actionable takeaways." },
      { role: "user", content: text.truncate(6000) }
    ],
    temperature: 0.3
  }
)

render plain: summary.dig("choices", 0, "message", "content")

rescue => e
  render json: { error: e.class.to_s, message: e.message }, status: 500
end


  private

  def authenticate
    provided = request.headers["Authorization"]&.split("Bearer ")&.last
    expected = ENV["GPT_AUTH_TOKEN"]
    unless ActiveSupport::SecurityUtils.secure_compare(provided.to_s, expected.to_s)
      render json: { error: "Unauthorized" }, status: 401
    end
  end
end
