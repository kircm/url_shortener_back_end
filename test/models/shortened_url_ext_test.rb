require 'test_helper'

class ShortenedUrlExtTest < ActiveSupport::TestCase
  include Shortener

  # Test utility methods
  class UtilityMethodsTest < ShortenedUrlExtTest
    test "should normalize URL" do
      Shortener::auto_clean_url = true
      normalized = ShortenedUrlExt.normalize_url("http://www..example.com?par1=val1")
      assert_equal("http://www..example.com/?par1=val1", normalized)
    end

    test "should select expired object from list of objects" do
      now = Time.current
      some_non_expired = OpenStruct.new(id: 1, expires_at: nil)
      some_expired = OpenStruct.new(id: 2, expires_at: now - 1.day)
      other_non_expired = OpenStruct.new(id: 3, expires_at: now + 1.day)

      shortened_urls = [some_non_expired, some_expired, other_non_expired]

      expired = ShortenedUrlExt.expired(shortened_urls)

      assert_not_includes(expired, some_non_expired, "it included a non-expired object")
      assert_includes(expired, some_expired, "the expired object is missing")
      assert_not_includes(expired, other_non_expired, "it included a non-expired object")
    end
  end

  # Test the creation of shortened urls using dynamic slug
  class CreateDynamicSlugTest < ShortenedUrlExtTest
    test "should create new shortened url with dynamic slug" do
      created1 = ShortenedUrlExt.create_with_dynamic_slug("http://www.example.com/")

      assert_not_empty(created1.shortened_url.unique_key)
    end

    test "should create new shortened url with dynamic slug - idempotent" do
      long_url = "http://www.example.com/"
      created1 = ShortenedUrlExt.create_with_dynamic_slug(long_url)
      created2 = ShortenedUrlExt.create_with_dynamic_slug(long_url)

      assert_not_empty(created1.shortened_url.unique_key)
      assert_equal(created1.shortened_url.unique_key, created2.shortened_url.unique_key)
    end

    test "should return existing dynamic slug" do
      long_url = "http://example.com/"
      existing_slug = "12345"
      Shortener::ShortenedUrl.generate!(long_url, custom_key: existing_slug)
      created = ShortenedUrlExt.create_with_dynamic_slug(long_url)

      assert_equal(existing_slug, created.shortened_url.unique_key)
    end

    test "should un-expire existing dynamic slug" do
      long_url = "http://example.com/"
      existing_slug = "12345"
      expires_at = Time.current - 1.day
      Shortener::ShortenedUrl.generate!(long_url, expires_at: expires_at, custom_key: existing_slug)
      created = ShortenedUrlExt.create_with_dynamic_slug(long_url)

      assert_equal(existing_slug, created.shortened_url.unique_key)
      assert_nil(created.shortened_url.expires_at)
    end
  end


  # Test the creation of shortened urls using custom slug
  class CreateCustomSlugTest < ShortenedUrlExtTest
    test "should create new shortened url with custom slug" do
      custom_slug = "custom"
      created1 = ShortenedUrlExt.create_with_custom_slug("http://www.example.com/", custom_slug)

      assert_not_empty(created1.shortened_url.unique_key)
      assert_equal(custom_slug, created1.shortened_url.unique_key)
    end

    test "should create new shortened url with custom slug - idempotent" do
      custom_slug = "custom"
      long_url = "http://www.example.com/"
      created1 = ShortenedUrlExt.create_with_custom_slug(long_url, custom_slug)
      created2 = ShortenedUrlExt.create_with_custom_slug(long_url, custom_slug)

      assert_not_empty(created1.shortened_url.unique_key)
      assert_not_empty(created2.shortened_url.unique_key)
      assert_equal(custom_slug, created1.shortened_url.unique_key)
      assert_equal(custom_slug, created2.shortened_url.unique_key)
    end

    test "should un-expire existing expired shortened url with same custom slug same url" do
      custom_slug = "12345"
      long_url = "http://example.com/"
      expires_at = Time.current - 1.day
      Shortener::ShortenedUrl.generate!(long_url, expires_at: expires_at, custom_key: custom_slug)

      created = ShortenedUrlExt.create_with_custom_slug(long_url, custom_slug)

      assert_nil(created.shortened_url.expires_at)
      assert_equal(custom_slug, created.shortened_url.unique_key)
      assert_equal(long_url, created.shortened_url.url)
    end

    test "should return error structure when custom slug collides with existing shortened url" do
      custom_slug = "12345"
      existing_long_url = "http://example.com/"
      Shortener::ShortenedUrl.generate!(existing_long_url, custom_key: custom_slug)

      new_long_url = "http://example2.com/"
      error_structure = ShortenedUrlExt.create_with_custom_slug(new_long_url, custom_slug)

      assert_equal("Slug already taken.", error_structure.error_message)
    end

    test "should reuse existing new shortened with same url same custom slug" do
      custom_slug = "custom"
      long_url = "http://www.example.com/"
      pre_existing = Shortener::ShortenedUrl.generate!(long_url, custom_key: custom_slug)

      created = ShortenedUrlExt.create_with_custom_slug(long_url, custom_slug)

      assert_equal(pre_existing, created.shortened_url)
    end
  end
end