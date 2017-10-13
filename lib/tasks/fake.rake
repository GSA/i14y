namespace :fake do
  desc "Creates a specified number of test documents for an existing collection"
  # Sample usage, to create 10 documents for the collection with handle 'my_drawer':
  # rake fake:documents[my_drawer,10]

  task :documents, [:index_name, :document_count] => [:environment] do |t, args|
    Document.index_name = Document.index_namespace(args[:index_name])
    count = args[:document_count].to_i

    count.times { Document.create(fake_doc) }
  end

  private

  def fake_doc
    { _id: Time.now.to_f.to_s,
      title: Faker::TwinPeaks.character,
      path: fake_url,
      created: [Faker::Time.between(3.years.ago, Date.today).to_json, nil].sample,
      description:  [nil, Faker::TwinPeaks.location].sample,
      content: quotes,
      promote: [true,false].sample,
      language: 'en',
      tags: %w(trees coffee pie).sample([1,2,3].sample).join(',')
    }
  end

  def fake_url
    domain = [ [nil,'www','coffee','pie'].sample, 'twinpeaks.gov'].compact.join('.')
    directories = [%w(plastic fish mill).sample, %w(gum whittling fire).sample].join('/')
    file = Faker::TwinPeaks.location.parameterize
    filetype = %w(html doc pdf).sample
    protocol = %w(http https).sample
    "#{protocol}://#{domain}/#{directories}/#{file}.#{filetype}"
  end

  def quotes
    quotes = ''
    10.times { quotes << Faker::TwinPeaks.quote + ' ' }
    quotes
  end
end
