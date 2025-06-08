require "google/apis/drive_v3"
require "googleauth"
require "pdf-reader"
require "stringio"

class DocumentsController < ApplicationController
  before_action :authenticate

  def read
    file_id = params[:file_id]

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
    text = reader.pages.map(&:text).join("\n").encode("UTF-8", invalid: :replace, undef: :replace, replace: "")

    render json: { content: text }
  rescue => e
    render json: {
      error: e.class.to_s,
      message: e.message,
      backtrace: e.backtrace.take(5)
    }, status: 500
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
