shared_examples 'a data modifying request made during read-only mode' do
  let(:allow_updates) { false }

  it 'returns a read-only-mode-releated failure message as JSON' do
    expect(response.status).to eq(503)
    expect(JSON.parse(response.body)).to match(hash_including('status' => 503, 'developer_message' => 'The i14y API is currently in read-only mode.'))
  end
end
