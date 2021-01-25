# frozen_string_literal: true

shared_examples_for 'a repository' do
  describe 'serialization' do
    subject(:serialize) { repository.serialize(klass_instance) }

    let(:klass_instance) { repository.klass.new }

    it { is_expected.to be_a Hash }
  end

  describe 'deserialization' do
    subject(:deserialize) { repository.deserialize(hash) }

    # Ensures backwards compatibility with pre-ES 7 documents
    context 'when the source does not include the id' do
      let(:hash) do
        {
          '_id' => 'a123',
          '_source' => { }
        }
      end

      it 'sets the id on the deserialized object' do
        expect(deserialize.id).to eq 'a123'
      end
    end
  end

  it 'can connect to Elasticsearch' do
    expect(repository.client.ping).to be(true)
  end

  it 'uses one primary and one replica shard' do
    expect(repository.settings.to_hash).to match(hash_including(
      number_of_shards: 1,
      number_of_replicas: 1
    ))
  end
end
