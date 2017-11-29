class MaxBytes < Grape::Validations::Base
  def validate_param!(attr_name, params)
    if params[attr_name].bytesize > max_bytes
      fail Grape::Exceptions::Validation, params: [@scope.full_name(attr_name)], message: "cannot be more than #{max_bytes} bytes long"
    end
  end

  private

  def max_bytes
    @max_bytes ||= [@option].flatten.first
  end
end
