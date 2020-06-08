class ShortenedUrlExt
  include Shortener

  def self.normalize_url(url)
    Shortener::auto_clean_url ? ShortenedUrl.clean_url(url) : url
  end

  def self.expired(shortened_urls)
    shortened_urls.filter { |u| u.expires_at && u.expires_at < Time.current }
  end

  def self.find_expired_shortened_url_by_url(url)
    expired(ShortenedUrl.where(url: url)).first
  end

  def self.find_expired_shortened_url_by_slug(slug)
    ShortenedUrlExt.expired(ShortenedUrl.where(unique_key: slug)).first
  end

  def self.find_unexpired_shortened_url_by_slug(slug)
    ShortenedUrl.unexpired.where(unique_key: slug).first
  end

  def self.create_with_dynamic_slug(long_url_to_store)
    existing_expired = find_expired_shortened_url_by_url(long_url_to_store)

    if (existing_expired)
      # There is a previously existing short url record that has the same long url
      # We un-expire it
      existing_expired.update(expires_at: nil)
      OpenStruct.new(shortened_url: existing_expired)
    else
      shortened_url = Shortener::ShortenedUrl.generate(long_url_to_store)
      OpenStruct.new(shortened_url: shortened_url)
    end
  end

  def self.create_with_custom_slug(long_url_to_store, custom_slug)
    existing_same_slug_expired = find_expired_shortened_url_by_slug(custom_slug)
    if (existing_same_slug_expired)
      # There is a previously existing short url record that has the same slug
      # We un-expire it and modify long url to the new one
      existing_same_slug_expired.update(expires_at: nil, url: long_url_to_store)
      OpenStruct.new(shortened_url: existing_same_slug_expired)
    else
      existing_same_slug = find_unexpired_shortened_url_by_slug(custom_slug)
      if (existing_same_slug && existing_same_slug.url != long_url_to_store)
        # There is a previously existing short url record that has the same slug
        # holding a different long url - Error
        OpenStruct.new(error_message: "Slug already taken.")
      elsif (existing_same_slug && existing_same_slug.url == long_url_to_store)
        # There is a previously existing short url record that has the same slug
        # holding the same long url - we can reuse that
        OpenStruct.new(shortened_url: existing_same_slug)
      else
        # Generate brand new shortened url record
        shortened_url = ShortenedUrl.generate(long_url_to_store, **{custom_key: custom_slug, fresh: true})
        OpenStruct.new(shortened_url: shortened_url)
      end
    end
  end
end
