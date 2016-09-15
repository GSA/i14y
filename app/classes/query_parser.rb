class QueryParser
  SiteFilter = Struct.new(:domain_name, :url_path)
  attr_reader :site_filters

  def initialize(query)
    @query = query
    @site_filters = extract_site_filters
  end

  def remaining_query
    @query.gsub(/[()]/,'').squish
  end

  private
  def extract_site_filters
    site_filters = { included_sites: [], excluded_sites: [] }
    @query.gsub!(/(-?site:\S+)\b\/?/i) do
      match = $1
      if match.first == '-'
        site_filters[:excluded_sites] << extract_site_filter(match)
      else
        site_filters[:included_sites] << extract_site_filter(match)
      end
      nil
    end
    site_filters
  end

  def extract_site_filter(site_param)
    domain_name, url_path = site_param.split('/', 2)
    domain_name.sub!(/\A-?site:/i, '')
    url_path = url_path.present? ? "/#{url_path}" : nil
    SiteFilter.new domain_name, url_path
  end
end