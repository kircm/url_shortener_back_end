require 'test_helper'
require 'minitest/autorun'

class ShortenedUrlsControllerTest < ActionDispatch::IntegrationTest
  include Shortener

  def json_response
    ActiveSupport::JSON.decode @response.body
  end

  class ShowActionTest < ShortenedUrlsControllerTest
    test "should return 404 for non-existent short url" do
      slug = "abcd"
      controller_url = url_for({controller: "/shortener/shortened_urls", action: :show, id: slug, only_path: false})
      get controller_url
      assert_response :missing
    end

    test "should redirect to long url for existing short url" do
      existing_slug = "12345"
      long_url = "http://example.com/"
      Shortener::ShortenedUrl.generate!(long_url, custom_key: existing_slug)

      controller_url = url_for({controller: "/shortener/shortened_urls", action: :show, id: existing_slug, only_path: false})
      get controller_url
      assert_response :redirect
      assert_redirected_to long_url
    end
  end

  class CreateActionTest < ShortenedUrlsControllerTest
    test "creates short url with dynamic slug" do
      long_url = "http://example.com"
      normalized_url = "http://example.com/"
      created_slug = "12345"

      normalize_url_mock = Minitest::Mock.new
      normalize_url_mock.expect(:call, normalized_url, [long_url])

      expected_shortened_url = OpenStruct.new(shortened_url: OpenStruct.new(unique_key: created_slug))
      create_dynamic_slug_mock = Minitest::Mock.new
      create_dynamic_slug_mock.expect(:call, expected_shortened_url, [normalized_url])

      ShortenedUrlExt.stub(:normalize_url, normalize_url_mock) do
        ShortenedUrlExt.stub(:create_with_dynamic_slug, create_dynamic_slug_mock) do
          controller_url = url_for({controller: "/shortener/shortened_urls", action: :create, only_path: false})
          post controller_url, params: {url: long_url}

          assert_response :ok
          assert_equal "http://www.example.com/shortened_urls/#{created_slug}", json_response['short_url']
        end
      end

      assert_mock(normalize_url_mock)
      assert_mock(create_dynamic_slug_mock)
    end

    test "creates short url with custom slug" do
      long_url = "http://example.com/"
      custom_slug = "custom"

      expected_shortened_url = OpenStruct.new(shortened_url: OpenStruct.new(unique_key: custom_slug))

      create_custom_slug_mock = Minitest::Mock.new
      create_custom_slug_mock.expect(:call, expected_shortened_url, [long_url, custom_slug])

      ShortenedUrlExt.stub(:create_with_custom_slug, create_custom_slug_mock) do
        controller_url = url_for({controller: "/shortener/shortened_urls", action: :create, only_path: false})
        post controller_url, params: {url: long_url, custom_slug: custom_slug}

        assert_response :ok
        assert_equal "http://www.example.com/shortened_urls/#{custom_slug}", json_response['short_url']
      end

      assert_mock(create_custom_slug_mock)
    end
  end

  class DestroyActionTest < ShortenedUrlsControllerTest

    test "expires existing short url" do
      slug = "12345"

      update_mock = Minitest::Mock.new
      def update_mock.update(now); true; end

      find_unexpired_mock = Minitest::Mock.new
      find_unexpired_mock.expect(:call, update_mock, [slug])

      ShortenedUrlExt.stub(:find_unexpired_shortened_url_by_slug, find_unexpired_mock) do
        ShortenedUrl.stub(:update, update_mock) do
          controller_url = url_for({controller: "/shortener/shortened_urls", action: :destroy, id: slug, only_path: false})
          delete controller_url

          assert_response :ok
        end
      end

      assert_mock(find_unexpired_mock)
    end

    test "returns 404 when shortened url to delete not found" do
      slug = "12345"

      find_unexpired_mock = Minitest::Mock.new
      find_unexpired_mock.expect(:call, nil, [slug])

      ShortenedUrlExt.stub(:find_unexpired_shortened_url_by_slug, find_unexpired_mock) do
        controller_url = url_for({controller: "/shortener/shortened_urls", action: :destroy, id: slug, only_path: false})
        delete controller_url

        assert_response :not_found
      end

      assert_mock(find_unexpired_mock)
    end
  end
end