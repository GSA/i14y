require 'rails_helper'

describe DisallowedCharacters do
  subject(:validator) { described_class.new(attrs, options, required, scope.new) }
  let(:attrs) { nil }
  let(:required) { false }
  let(:scope) do
    Struct.new(:opts) do
      def full_name(name); end
    end
  end

  describe 'validate!' do
    context 'when disallowed characters option is an array of characters' do
      let(:options) { [%w[a e i o u]] }

      context 'and the value of the param being validated does not contain any of those characters' do
        let(:params) { { word: 'rhythms' } }

        it 'does not raise a validation exception' do
          expect { validator.validate_param!(:word, params) }.to_not raise_error
        end
      end

      context 'and the value of the param being validated contains at least one of those characters' do
        let(:params) { { word: 'apples' } }

        it 'raises a validation exception' do
          expect { validator.validate_param!(:word, params) }.to raise_error(Grape::Exceptions::Validation, "cannot contain any of the following characters: ['a','e','i','o','u']")
        end
      end
    end

    context 'when disallowed characters option is a single character' do
      let(:options) { 'e' }

      context 'and the value of the param being validated is not that character' do
        let(:params) { { word: 'q' } }

        it 'does not raise a validation exception' do
          expect { validator.validate_param!(:word, params) }.to_not raise_error
        end
      end

      context 'and the value of the param being validated is that character' do
        let(:params) { { word: 'e' } }

        it 'raises a validation exception' do
          expect { validator.validate_param!(:word, params) }.to raise_error(Grape::Exceptions::Validation, "cannot contain any of the following characters: ['e']")
        end
      end
    end
  end
end
