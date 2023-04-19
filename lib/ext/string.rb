class String
  def extract_array
    split(',').map(&:strip).map(&:downcase)
  end
end
