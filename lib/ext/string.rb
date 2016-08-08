class String
  def extract_array
    self.split(',').map(&:strip).map(&:downcase)
  end
end
