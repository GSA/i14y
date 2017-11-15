class DisallowedCharacters < Grape::Validations::Base
  def validate_param!(attr_name, params)
    if characters.any? { |c| params[attr_name].include?(c) }
      fail Grape::Exceptions::Validation, params: [@scope.full_name(attr_name)], message: "cannot contain any of the following characters: #{display_characters}"
    end
  end

  private

  def characters
    @characters ||= [@option].flatten
  end

  def display_characters
    '[' + characters.map { |c| "'#{c}'" }.join(',') + ']'
  end
end
