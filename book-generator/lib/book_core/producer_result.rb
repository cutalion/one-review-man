# frozen_string_literal: true

module BookCore
  ProducerResult = Struct.new(
    :success, :output_path, :canon_version, :artifacts, :error,
    keyword_init: true
  ) do
    def success?
      success == true
    end

    def failure?
      !success?
    end
  end
end
