class String

  def word_count
    split.count
  end

  def first_letter_for_grouping
    letter = self.downcase.first
    if letter.match?(/[a-z]/)
      letter
    else
      "#"
    end
  end

  def to_fs(format = :default)
    Date.parse(self).to_fs(format)
  end

end
