# frozen_string_literal: true

shared_examples 'a data modifying request made during read-only mode' do
  let(:allow_updates) { false }

  it 'returns a read-only-mode-releated failure message as JSON' do
    expect(response.status).to eq(503)
    expect(JSON.parse(response.body)).to match(hash_including({
      'status' => 503,
      'developer_message' => 'The i14y API is currently in read-only mode.'
    }))
  end

  context 'when a specific maintenance message is configured' do
    let(:maintenance_message) { 'Sorry about that!' }

    it 'additionally includes the specific maintanance message' do
      expect(JSON.parse(response.body)).to match(hash_including({
        'status' => 503,
        'developer_message' => 'The i14y API is currently in read-only mode. Sorry about that!'
      }))
    end
  end
end
