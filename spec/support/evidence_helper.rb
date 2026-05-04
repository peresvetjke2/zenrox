module EvidenceHelper
  def write_evidence(relative_path, payload, feature: "ft-001")
    path = Rails.root.join("artifacts", feature, "verify", relative_path)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, JSON.pretty_generate(payload))
  end
end
