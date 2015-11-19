class String
  def extract_tags
    self.split(',').map(&:strip).map(&:downcase)
  end
end
