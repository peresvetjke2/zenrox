module EvidenceHelper
  def write_evidence(relative_path, payload)
    path = Rails.root.join("artifacts/ft-001/verify", relative_path)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, JSON.pretty_generate(payload))
  end
end
