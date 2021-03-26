# frozen_string_literal: true

require 'rails_helper'

TWO_BYTE_CHARACTER = "\u00b5"

describe MaxBytes do
  subject(:validator) { described_class.new(attrs, options, required, scope.new) }
  let(:attrs) { nil }
  let(:options) { [10] }
  let(:required) { false }
  let(:scope) do
    Struct.new(:opts) do
      def full_name(name); end
    end
  end

  describe 'validate!' do
    let(:params) { { some_param: value_to_validate } }
    context 'when the value of the param being validated has fewer than tha maximum number of bytes' do
      let(:value_to_validate) { TWO_BYTE_CHARACTER }

      it 'does not raise a validation exception' do
        expect { validator.validate_param!(:some_param, params) }.to_not raise_error
      end
    end

    context 'when the value of the param being validated has exactly the maximum number of bytes' do
      let(:value_to_validate) { TWO_BYTE_CHARACTER * 5 }

      it 'does not raise a validation exception' do
        expect { validator.validate_param!(:some_param, params) }.to_not raise_error
      end
    end

    context 'when the value of the param being validated has more than tha maximum number of bytes' do
      let(:value_to_validate) { TWO_BYTE_CHARACTER * 5 + 'z' }

      it 'raises a validation exception' do
        expect { validator.validate_param!(:some_param, params) }.to raise_error(Grape::Exceptions::Validation, 'cannot be more than 10 bytes long')
      end
    end
  end
end
